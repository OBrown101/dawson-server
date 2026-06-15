//
//  WebSocketSecurity.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/14/26.
//

import Foundation

final class WebSocketSecurity {
    
    static let directory = DAWSON.workspace.appendingPathComponent("security")
    static let certPath = directory.appendingPathComponent("fullchain.pem")
    static let keyPath = directory.appendingPathComponent("privkey.pem")
    static let tokenPath = directory.appendingPathComponent("auth-token.txt")

    static func setup() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        if (!FileManager.default.fileExists(atPath: certPath.path) ||
            !FileManager.default.fileExists(atPath: keyPath.path)) {

            let _ = try runAndCapture("openssl", [
                "req",
                "-x509",
                "-newkey", "rsa:4096",
                "-keyout", keyPath.path,
                "-out", certPath.path,
                "-days", "3650",
                "-nodes",
                "-subj", "/CN=DAWSON Local"
            ])
        }

        if !FileManager.default.fileExists(atPath: tokenPath.path) {
            let token = try runAndCapture("openssl", ["rand", "-hex", "32"])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            try token.write(to: tokenPath, atomically: true, encoding: .utf8)
        }
        
        print("====================================")
        print("DAWSON SERVER")
        print("Auth Token: \(try authToken())")
        print("Fingerprint: \(try certificateFingerprint())")
        print("====================================")
    }

    static func authToken() throws -> String {
        try String(contentsOf: tokenPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func certificateFingerprint() throws -> String {
        let output = try runAndCapture("openssl", [
            "x509",
            "-in", certPath.path,
            "-noout",
            "-fingerprint",
            "-sha256"
        ])

        return output
            .replacingOccurrences(of: "sha256 Fingerprint=", with: "")
            .replacingOccurrences(of: "SHA256 Fingerprint=", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func runAndCapture(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "WebSocketSecurity",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output]
            )
        }

        return output
    }
}

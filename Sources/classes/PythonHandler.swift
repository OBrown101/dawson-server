//
//  PythonHandler.swift
//
//
//  Created by Ethan Brown on 4/26/26.
//

import Foundation

class PythonHandler {
    private let pythonPath: URL     // Full path to interpreter
    private let scriptPath: URL     // Full path to Python script

    /// Optional environment dictionary.  By default the handler
    /// augments the current process’s PATH so the venv’s `bin`
    /// (or `Scripts`) directory is first.  That guarantees the
    /// interpreter you launched is the one from the venv.
    private var env: [String: String]
    
    init(script: String, projectRoot: URL? = nil) throws {
        let root = projectRoot ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        #if os(Windows)
        self.pythonPath = root      // python/Scripts/python.exe
            .appendingPathComponent("python")
            .appendingPathComponent("Scripts")
            .appendingPathComponent("python.exe")
        #else
        self.pythonPath = root      // python/venv/bin/python3
            .appendingPathComponent("python")
            .appendingPathComponent("venv")
            .appendingPathComponent("bin")
            .appendingPathComponent("python3")
        #endif
        
        guard FileManager.default.fileExists(atPath: pythonPath.path) else {
            throw NSError(domain: "PythonHandler", code: 1, userInfo: [NSLocalizedDescriptionKey: "Python interpreter not found at \(pythonPath.path)"])
        }

        scriptPath = root.appendingPathComponent(script)

        guard FileManager.default.fileExists(atPath: scriptPath.path) else {
            throw NSError(domain: "PythonHandler", code: 2, userInfo: [NSLocalizedDescriptionKey: "Python script not found at \(scriptPath.path)"])
        }

        // Augment PATH so the venv’s bin/Scripts dir is first.
        var environment = ProcessInfo.processInfo.environment
        let venvBin = pythonPath.deletingLastPathComponent().path
        environment["PATH"] = "\(venvBin):\(environment["PATH"] ?? "")"
        self.env = environment
    }
    
    private func run(input: [String: Any]) throws -> [String: Any] {
        let inputData = try JSONSerialization.data(withJSONObject: input, options: [])

        let process = Process()
        process.executableURL = pythonPath
        process.arguments = [scriptPath.path]
        process.environment = env

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = Pipe()

        try process.run()

        // Write JSON payload to the script’s stdin
        stdinPipe.fileHandleForWriting.write(inputData)
        stdinPipe.fileHandleForWriting.closeFile()

        // Wait for the process to finish
        process.waitUntilExit()
        if (process.terminationStatus != 0) {
            let errData = (process.standardError as! Pipe).fileHandleForReading.readDataToEndOfFile()
            let errString = String(data: errData, encoding: .utf8) ?? "unknown error"
            throw NSError(domain: "PythonHandler", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Python script failed: \(errString)"])
        }

        // Read JSON response from stdout
        let outputData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        guard let outputDict = try JSONSerialization.jsonObject(with: outputData, options: []) as? [String: Any] else {
            throw NSError(domain: "PythonHandler", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to decode JSON from Python script output"])
        }

        return outputDict
    }
    
    func call(method: String, params: [String: Any]) throws -> [String: Any]? {
        let input: [String: Any] = [
            "method": method,
            "params": params
        ]
        
        let result = try run(input: input)
        print(String(describing: result))
        if (result["error"] != nil) { return nil }

        return result["result"] as? [String: Any]
    }
}

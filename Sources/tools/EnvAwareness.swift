//
//  EnvAwareness.swift
//
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation

class EnvAwareness: ChatSessionAware {
    let name = "environmental_awareness"
    private var session: ChatSessionInfo?

    func setSession(_ session: ChatSessionInfo) {
        self.session = session
    }

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Provides agent with current environmental awareness data such as time/date, timezone, operating system, DAWSON project root and workspace directories, etc.",
                "parameters": [
                    "type": "object",
                    "required": [],
                    "properties": [:]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let session = session else {
            return "Invalid chat session. Developer error."
        }
        do {
            try ToolPermissionGuard.guardRead(session: session)
        } catch {
            return String(describing: error)
        }
        
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        formatter.timeZone = TimeZone.current
        
        let dateString = formatter.string(from: now)
        let timezoneName = TimeZone.current.identifier
        let user = NSUserName()
        let osInfo = getOSInfo()

        let info = """
        Date & time: \(dateString)
        Time zone: \(timezoneName)
        Current Host Computer info: \(getOSInfo())
        Current Host Computer user: \(user)
        DAWSON program root directory: \(DAWSON.root)
        DAWSON workspace directory: \(DAWSON.workspace)
        """

        return info
    }
    
    private func getOSInfo() -> String {
        let processInfo = ProcessInfo.processInfo
        #if os(macOS)
        return "macOS (version: \(processInfo.operatingSystemVersionString))"
        #elseif os(Linux)
        // Try common Linux version files
        var linuxVersion = "Linux (unknown distribution)"
        if let osRelease = try? String(contentsOfFile: "/etc/os-release", encoding: .utf8) {
            linuxVersion = "Linux - " + (osRelease.components(separatedBy: .newlines).first { $0.hasPrefix("PRETTY_NAME") } ?? "Unknown")
        }
        return "\(linuxVersion) (kernel: \(processInfo.operatingSystemVersionString)"
        #elseif os(Windows)
        return "Windows (version: \(processInfo.operatingSystemVersionString))"
        #else
        return "Unknown Platform"
        #endif
    }
}

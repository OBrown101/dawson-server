//
//  ShellCmd.swift
//  
//
//  Created by Ethan Brown on 3/19/26.
//

import Foundation

class Shell: Tool {
    let name = "shell"

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Executes a shell command on Linux, macOS, or Windows and returns stdout/stderr",
                "parameters": [
                    "type": "object",
                    "required": ["command"],
                    "properties": [
                        "command": [
                            "type": "string",
                            "description": "The shell command to execute"
                        ]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let command = args["command"] as? String, !command.isEmpty else {
            return "Error: No command provided."
        }
        
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        #if os(Windows)
        process.executableURL = URL(fileURLWithPath: "C:\\Windows\\System32\\cmd.exe")
        process.arguments = ["/c", command]
        #else
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        #endif

        do {
            try process.run()
            process.waitUntilExit()

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            let stdout = String(data: stdoutData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if process.terminationStatus == 0 {
                return stdout
            } else {
                return "Error:\nSTDOUT:\n\(stdout)\nSTDERR:\n\(stderr)"
            }

        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}

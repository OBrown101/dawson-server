//
//  ProcessMonitor.swift
//  
//
//  Created by Ethan Brown on 3/31/26.
//

import Foundation

class ProcessMonitor: Tool {
    let name = "process_monitor"

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Lists running processes on the system.",
                "parameters": [
                    "type": "object",
                    "required": [],
                    "properties": [:]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) -> String {
        #if os(macOS) || os(Linux)
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-e", "-o", "pid,comm"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? "Error reading processes."
        #elseif os(Windows)
        let task = Process()
        task.launchPath = "powershell"
        task.arguments = ["-Command", "Get-Process | Format-Table Id, ProcessName"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? "Error reading processes."
        #endif
    }
}

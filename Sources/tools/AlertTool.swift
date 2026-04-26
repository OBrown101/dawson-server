//
//  AlertTool.swift
//  
//
//  Created by Ethan Brown on 3/31/26.
//

import Foundation

class AlertTool: Tool {
    let name = "alert_tool"

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Shows a simple UI alert with a message (cross-platform).",
                "parameters": [
                    "type": "object",
                    "required": ["message"],
                    "properties": [
                        "message": [
                            "type": "string",
                            "description": "Message to display"
                        ]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) -> String {
        guard let message = args["message"] as? String else {
            return "Error: Missing message."
        }

        #if os(macOS)
        let script = "display alert \"\(message)\""
        _ = Process.launchedProcess(launchPath: "/usr/bin/osascript", arguments: ["-e", script])
        #elseif os(Linux)
        print("ALERT: \(message)") // Linux CLI fallback
        #elseif os(Windows)
        let ps = """
        [System.Windows.Forms.MessageBox]::Show('\(message)')
        """
        _ = Process.launchedProcess(launchPath: "powershell", arguments: ["-Command", ps])
        #endif

        return "Alert displayed."
    }
}

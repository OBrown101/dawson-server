//
//  WriteFile.swift
//  
//
//  Created by Ethan Brown on 3/20/26.
//

import Foundation

class WriteFile: ChatSessionAware {
    let name = "write_file"
    private var session: ChatSessionInfo?

    func setSession(_ session: ChatSessionInfo) {
        self.session = session
    }

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Writes content to a file at the specified path. Overwrites existing content if the file exists. Used for writing to any file.",
                "parameters": [
                    "type": "object",
                    "required": ["path", "content"],
                    "properties": [
                        "path": [
                            "type": "string",
                            "description": "The full path of the file to write"
                        ],
                        "content": [
                            "type": "string",
                            "description": "The text content to write to the file"
                        ]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String : Any]) async -> String {
        guard let path = args["path"] as? String, !path.isEmpty else {
            return "Error: No path provided."
        }
        guard let content = args["content"] as? String else {
            return "Error: No content provided."
        }
        guard let session = session else {
            return "Invalid chat session. Developer error."
        }
        do {
            try ToolPermissionGuard.guardCommands(session: session)
        } catch {
            return String(describing: error)
        }
        
        do {
            let fileURL = URL(fileURLWithPath: path)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return "Successfully wrote to \(path)"
        } catch let error {
            return "Error writing file at \(path): \(error.localizedDescription)"
        }
    }
}

//
//  WriteFile.swift
//  
//
//  Created by Ethan Brown on 3/20/26.
//

import Foundation

class WriteFile: Tool {
    let name = "write_file"

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

    func execute(args: [String: Any]) -> String {
        guard let path = args["path"] as? String, !path.isEmpty else {
            return "Error: No path provided."
        }
        guard let content = args["content"] as? String else {
            return "Error: No content provided."
        }
        
        let fileURL = URL(fileURLWithPath: path)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return "Successfully wrote to \(path)"
        } catch {
            return "Error writing file at \(path): \(error.localizedDescription)"
        }
    }
}

//
//  ReadFile.swift
//  
//
//  Created by Ethan Brown on 3/20/26.
//

import Foundation

class ReadFile: Tool {
    let name = "read_file"

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Reads the contents of a file at a given path and returns it as a string. Used for reading any file, including your SOUL, MEMORY, etc. config files.",
                "parameters": [
                    "type": "object",
                    "required": ["path"],
                    "properties": [
                        "path": [
                            "type": "string",
                            "description": "The full path of the file to read"
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
        
        let fileURL = URL(fileURLWithPath: path)
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            return content
        } catch {
            return "Error reading file at \(path): \(error.localizedDescription)"
        }
    }
}

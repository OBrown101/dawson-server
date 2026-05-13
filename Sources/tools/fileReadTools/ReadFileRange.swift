//
//  ReadFileRange.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/10/26.
//

import Foundation

class ReadFileRange: Tool {
    let name = "read_file_range"

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": """
                Reads only a specific range of lines from a file.
                This is the ONLY safe way to read file contents.
                Must be used after index_file or search_file.
                """,
                "parameters": [
                    "type": "object",
                    "required": ["path", "startLine", "endLine"],
                    "properties": [
                        "path": [
                            "type": "string",
                            "description": "File path"
                        ],
                        "startLine": [
                            "type": "integer",
                            "description": "Starting line (1-based)"
                        ],
                        "endLine": [
                            "type": "integer",
                            "description": "Ending line (1-based inclusive)"
                        ]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) -> String {
        guard
            let path = args["path"] as? String,
            let startLine = args["startLine"] as? Int,
            let endLine = args["endLine"] as? Int
        else {
            return "Error: missing required parameters"
        }

        let url = URL(fileURLWithPath: path)

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            guard startLine > 0, endLine <= lines.count, startLine <= endLine else {
                return "Error: invalid line range"
            }

            let slice = lines[(startLine - 1)...(endLine - 1)]
                .enumerated()
                .map { "\($0.offset + startLine): \($0.element)" }
                .joined(separator: "\n")

            return """
            File: \(path)
            Range: \(startLine)-\(endLine)

            \(slice)
            """

        } catch {
            return "Error reading file: \(error.localizedDescription)"
        }
    }
}

//
//  IndexFileContents.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/10/26.
//

import Foundation

class IndexFileContents: Tool {
    let name = "index_file_contents"

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": """
                Creates a lightweight index of a file without returning its full contents.
                Works for any file type (text, logs, code, markdown, etc).

                Returns:
                - line ranges
                - detected sections (functions/classes/headers where applicable)
                - basic heuristics (paragraph blocks for text files)
                """,
                "parameters": [
                    "type": "object",
                    "required": ["path"],
                    "properties": [
                        "path": [
                            "type": "string",
                            "description": "Full file path to index"
                        ]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) -> String {
        guard let path = args["path"] as? String else {
            return "Error: missing path"
        }

        let url = URL(fileURLWithPath: path)

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            var blocks: [[String: Any]] = []
            var currentStart = 1

            // Generic heuristic: split into blocks by blank lines
            for (i, line) in lines.enumerated() {
                let isLast = i == lines.count - 1
                let isBlank = line.trimmingCharacters(in: .whitespaces).isEmpty

                if isBlank || isLast {
                    let end = isLast ? i + 1 : i

                    if end >= currentStart {
                        let block = Array(lines[(currentStart - 1)..<max(currentStart, end)])
                        let preview = block.prefix(3).joined(separator: " ")

                        blocks.append([
                            "startLine": currentStart,
                            "endLine": end,
                            "preview": preview
                        ])
                    }

                    currentStart = i + 2
                }
            }

            return """
            {
                "file": "\(path)",
                "totalLines": \(lines.count),
                "blocks": \(blocks)
            }
            """

        } catch {
            return "Error indexing file: \(error.localizedDescription)"
        }
    }
}

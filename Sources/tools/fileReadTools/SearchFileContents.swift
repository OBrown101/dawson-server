//
//  SearchFileContents.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/10/26.
//

import Foundation

class SearchFileContents: Tool {
    let name = "search_file_contents"

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": """
                Searches inside a file for text matches.
                Returns matching lines with context.
                This is the primary way to locate relevant sections before reading.
                """,
                "parameters": [
                    "type": "object",
                    "required": ["path", "query"],
                    "properties": [
                        "path": [
                            "type": "string",
                            "description": "File path"
                        ],
                        "query": [
                            "type": "string",
                            "description": "Search string or keyword"
                        ]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) -> String {
        guard
            let path = args["path"] as? String,
            let query = args["query"] as? String
        else {
            return "Error: missing path or query"
        }

        let url = URL(fileURLWithPath: path)

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            var results: [[String: Any]] = []

            for (i, line) in lines.enumerated() {
                if line.localizedCaseInsensitiveContains(query) {
                    let start = max(0, i - 2)
                    let end = min(lines.count - 1, i + 2)

                    let context = lines[start...end].joined(separator: "\n")

                    results.append([
                        "line": i + 1,
                        "match": line,
                        "context": context
                    ])
                }
            }

            return """
            {
                "query": "\(query)",
                "matches": \(results)
            }
            """

        } catch {
            return "Error searching file: \(error.localizedDescription)"
        }
    }
}

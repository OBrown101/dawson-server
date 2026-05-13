//
//  ReadFile.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/10/26.
//

import Foundation

class ReadFile: Tool {
    let name = "read_file"

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": """
                Intelligent file reader that automatically:
                1. indexes file
                2. searches for relevance
                3. reads only needed ranges

                This is a convenience wrapper over \(IndexFileContents().name) + \(SearchFileContents().name) + \(ReadFileRange().name).
                """,
                "parameters": [
                    "type": "object",
                    "required": ["path", "query"],
                    "properties": [
                        "path": [
                            "type": "string"
                        ],
                        "query": [
                            "type": "string",
                            "description": "What you're looking for in the file"
                        ]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) -> String {
        return """
        This tool is a router-only tool.

        Workflow should be:

        1. \(IndexFileContents().name)
        2. \(SearchFileContents().name)
        3. \(ReadFileRange().name)

        Do not use this tool for raw reading.
        """
    }
}

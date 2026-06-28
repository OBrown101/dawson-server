//
//  ReadFile.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/17/26.
//

class ReadFile: PermissionAware {
    let name = "read_file"
    let description = "Reads a file. Optionally reads only a specific line range and can prefix lines with line numbers. Returns the file path and visible line range. If file is long, read only the specific line range of interest."
    
    func permissionRequests(args: [String : Any]) -> [PermissionRequest] {
        guard let path = args["path"] as? String,
              !path.isEmpty else { return [] }
        
        return [
            PermissionRequest(action: .read, target: path)
        ]
    }
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": name,
            "description": description,
            "parameters": [
                "type": "object",
                "properties": [
                    "path": [
                        "type": "string",
                        "description": "The file to read"
                    ],
                    "start": [
                        "type": "integer",
                        "description": "Starting line number (1‑based)"
                    ],
                    "end": [
                        "type": "integer",
                        "description": "Ending line number (1‑based, inclusive)"
                    ],
                    "show_line_numbers": [
                        "type": "boolean",
                        "description": "Whether to prefix each line with its line number",
                        "default": false
                    ]
                ],
                "required": ["path"]
            ]
        ]
    }
    
    func anthropicSchema() -> [String : Any] {
        return [
            "name": name,
            "description": description,
            "input_schema": [
                "type": "object",
                "properties": [
                    "path": [
                        "type": "string",
                        "description": "The file to read"
                    ],
                    "start": [
                        "type": "integer",
                        "description": "Starting line number (1‑based)"
                    ],
                    "end": [
                        "type": "integer",
                        "description": "Ending line number (1‑based, inclusive)"
                    ],
                    "show_line_numbers": [
                        "type": "boolean",
                        "description": "Whether to prefix each line with its line number",
                        "default": false
                    ]
                ],
                "required": ["path"]
            ]
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "required": ["path"],
                    "properties": [
                        "path": [
                            "type": "string",
                            "description": "The file to read"
                        ],
                        "start": [
                            "type": "integer",
                            "description": "Starting line number (1-based)"
                        ],
                        "end": [
                            "type": "integer",
                            "description": "Ending line number (1-based, inclusive)"
                        ],
                        "show_line_numbers": [
                            "type": "boolean",
                            "description": "Whether to prefix each line with its line number",
                            "default": false
                        ]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let path = args["path"] as? String, !path.isEmpty else {
            return "Error: No path provided."
        }

        let start = args["start"] as? Int
        let end = args["end"] as? Int
        let showLineNumbers = args["show_line_numbers"] as? Bool ?? false

        do {
            let text = try String(contentsOfFile: path, encoding: .utf8)
            let lines = text.components(separatedBy: .newlines)

            let startLine = max(1, start ?? 1)
            let endLine = min(lines.count, end ?? lines.count)

            guard startLine <= endLine else {
                return "Error: Invalid line range."
            }

            var output: [String] = []

            for lineNumber in startLine...endLine {
                let line = lines[lineNumber - 1]
                if showLineNumbers {
                    output.append("\(lineNumber): \(line)")
                } else {
                    output.append(line)
                }
            }

            let header = "File: \(path)\nLines: \(startLine)-\(endLine) of \(lines.count)\n"
            return header + output.joined(separator: "\n")
        } catch {
            return "Error reading file: \(error.localizedDescription)"
        }
    }
}

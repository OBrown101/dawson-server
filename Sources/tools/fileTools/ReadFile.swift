//
//  ReadFile.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/17/26.
//

import Foundation

class ReadFile: PermissionAware {
    let name = "read_file"
    let description = "Reads a file. Optionally reads only a specific line range and can prefix lines with line numbers. Returns the file path and visible line range. If file is long, read only the specific line range of interest."
    
    private let maxFileSize = 500_000  // 500KB limit
    private let maxLinesWithoutRange = 100  // If no range specified, max 100 lines
    
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
            let fileURL = URL(fileURLWithPath: path)
            let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            
            // Prevent reading massive files without line range
            if fileSize > maxFileSize {
                return "Error: File too large (\(fileSize) bytes > \(maxFileSize) limit). Use start/end parameters to read specific line range."
            }

            let text = try String(contentsOfFile: path, encoding: .utf8)
            let lines = text.components(separatedBy: .newlines)

            let startLine = max(1, start ?? 1)
            let endLine: Int
            
            // Auto-limit if no range specified
            if start == nil && end == nil {
                endLine = min(lines.count, maxLinesWithoutRange)
                if lines.count > maxLinesWithoutRange {
                    let suggestion = "File has \(lines.count) total lines. Showing first \(maxLinesWithoutRange). Use start/end to read specific range."
                    let output = formatLines(lines[startLine-1..<endLine], start: startLine, showLineNumbers: showLineNumbers)
                    return suggestion + "\n\n" + output
                }
            } else {
                endLine = min(lines.count, end ?? lines.count)
            }

            guard startLine <= endLine && startLine <= lines.count else {
                return "Error: Invalid line range."
            }

            let output = formatLines(lines[startLine-1..<endLine], start: startLine, showLineNumbers: showLineNumbers)
            return output
        } catch {
            return "Error reading file: \(error.localizedDescription)"
        }
    }
    
    private func formatLines(_ lines: ArraySlice<String>, start: Int, showLineNumbers: Bool) -> String {
        let formatted = lines.enumerated().map { index, line in
            let lineNum = start + index
            return showLineNumbers ? "\(lineNum): \(line)" : line
        }.joined(separator: "\n")
        return formatted
    }
}

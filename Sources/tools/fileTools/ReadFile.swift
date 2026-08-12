//
//  ReadFile.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/17/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

class ReadFile: PermissionAware {
    static let name = "read_file"
    let description = "Reads a file at an exact path. The path must be an absolute path or a valid path relative to the current working directory. Do not pass only a filename like README.md or main.swift unless that exact relative path is known to exist. Use find_file first to locate files by name, then pass the returned absolute path to read_file. Can read a specific line range (start/end) and can prefix lines with line numbers for navigation — never include those 'N:' prefixes in text passed to replace_in_file. Every result begins with a header showing the visible range and the file's total line count. For long files, read only the line range of interest."

    private let maxFileSize = 500_000        // 500KB limit for unranged reads
    private let maxRangedFileSize = 10_000_000  // 10MB hard cap even with a range
    private let maxLinesWithoutRange = 100   // If no range specified, max 100 lines

    func permissionRequests(args: [String : Any]) -> [PermissionRequest] {
        guard let path = args["path"] as? String,
              !path.isEmpty else { return [] }

        return [
            PermissionRequest(action: .read, target: path)
        ]
    }

    private let parametersSchema: [String: Any] = [
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
                "description": "Whether to prefix each line with its line number (navigation only — never include these prefixes in replace_in_file text)",
                "default": false
            ]
        ]
    ]

    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": ReadFile.name,
            "description": description,
            "parameters": parametersSchema
        ]
    }

    func anthropicSchema() -> [String : Any] {
        return [
            "name": ReadFile.name,
            "description": description,
            "input_schema": parametersSchema
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": ReadFile.name,
                "description": description,
                "parameters": parametersSchema
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
        let hasRange = (start != nil || end != nil)

        guard FileManager.default.fileExists(atPath: path) else {
            return "Error: File not found at '\(path)'. Use find_file to locate the correct path, then read that absolute path."
        }

        do {
            let fileURL = URL(fileURLWithPath: path)
            let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0

            if (fileSize > maxRangedFileSize) {
                return "Error: File too large (\(fileSize) bytes > \(maxRangedFileSize) limit) to read with this tool."
            }

            if (!hasRange && fileSize > maxFileSize) {
                return "Error: File too large (\(fileSize) bytes > \(maxFileSize) limit) to read whole. Provide start/end parameters to read a specific line range."
            }

            let text: String
            do {
                text = try String(contentsOfFile: path, encoding: .utf8)
            } catch {
                return "Error: '\(path)' is not readable as UTF-8 text. It may be a binary file; use a format-specific tool (e.g. read_pdf for PDFs)."
            }

            let lines = text.components(separatedBy: .newlines)
            let startLine = max(1, start ?? 1)
            let endLine: Int
            var note = ""

            if (!hasRange) {
                endLine = min(lines.count, maxLinesWithoutRange)
                if (lines.count > maxLinesWithoutRange) {
                    note = " (file continues; use start/end for more)"
                }
            } else {
                endLine = min(lines.count, end ?? lines.count)
            }

            guard startLine <= endLine && startLine <= lines.count else {
                return "Error: Invalid line range. This file has \(lines.count) lines; requested start \(startLine)."
            }

            let header = "== \(path) (lines \(startLine)-\(endLine) of \(lines.count))\(note) =="
            let body = formatLines(lines[startLine-1..<endLine], start: startLine, showLineNumbers: showLineNumbers)
            return header + "\n" + body
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

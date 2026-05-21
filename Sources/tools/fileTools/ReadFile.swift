//
//  ReadFile.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/17/26.
//

class ReadFile: ChatSessionAware {
    let name = "read_file"
    private var session: ChatSessionInfo?

    func setSession(_ session: ChatSessionInfo) {
        self.session = session
    }

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description":
                """
                Reads a file. Optionally reads only a specific line range and can prefix lines with line numbers. If file is long, DO NOT read the entire content, you should read only the specific line range of interest.
                """,
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

        guard let session = session else {
            return "Invalid chat session. Developer error."
        }
        
        do {
            try ToolPermissionGuard.guardRead(from: path, session: session)
        } catch {
            return String(describing: error)
        }

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

            return output.joined(separator: "\n")
        } catch {
            return "Error reading file: \(error.localizedDescription)"
        }
    }
}

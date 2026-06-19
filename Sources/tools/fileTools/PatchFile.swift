//
//  PatchFile.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/17/26.
//

class PatchFile: PermissionAware {
    let name = "path_file"
    
    func permissionRequests(args: [String : Any]) -> [PermissionRequest] {
        guard let path = args["path"] as? String,
                !path.isEmpty else { return [] }
        guard let diff = args["diff"] as? String,
                !diff.isEmpty else { return [] }
        
        return [
            PermissionRequest(action: .read, target: path),
            PermissionRequest(action: .write, target: path)
        ]
    }
    
    func openAISchema() -> [String : Any] {
        return [
            "name": name,
            "description": "Applies a simple unified diff patch to a file. Supports a single hunk.",
            "parameters": [
                "type": "object",
                "properties": [
                    "path": [
                        "type": "string",
                        "description": "The file to patch"
                    ],
                    "diff": [
                        "type": "string",
                        "description": "A unified diff patch"
                    ]
                ],
                "required": ["path", "diff"]
            ]
        ]
    }
    
    func anthropicSchema() -> [String : Any] {
        return [
            "name": name,
            "description": "Applies a simple unified diff patch to a file. Supports a single hunk.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "path": [
                        "type": "string",
                        "description": "The file to patch"
                    ],
                    "diff": [
                        "type": "string",
                        "description": "A unified diff patch"
                    ]
                ],
                "required": ["path", "diff"]
            ]
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Applies a simple unified diff patch to a file. Supports a single hunk.",
                "parameters": [
                    "type": "object",
                    "required": ["path", "diff"],
                    "properties": [
                        "path": [
                            "type": "string",
                            "description": "The file to patch"
                        ],
                        "diff": [
                            "type": "string",
                            "description": "A unified diff patch"
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

        guard let diff = args["diff"] as? String, !diff.isEmpty else {
            return "Error: No diff provided."
        }
        
        do {
            var content = try String(contentsOfFile: path, encoding: .utf8)
            let diffLines = diff.components(separatedBy: .newlines)

            var removedLines: [String] = []
            var addedLines: [String] = []
            var inHunk = false

            for line in diffLines {
                if line.hasPrefix("@@") {
                    inHunk = true
                    continue
                }

                guard inHunk else { continue }

                if line.hasPrefix("-") {
                    removedLines.append(String(line.dropFirst()))
                } else if line.hasPrefix("+") {
                    addedLines.append(String(line.dropFirst()))
                } else if line.hasPrefix(" ") {
                    continue
                }
            }

            let oldBlock = removedLines.joined(separator: "\n")
            let newBlock = addedLines.joined(separator: "\n")

            guard (!oldBlock.isEmpty) else {
                return "Error: No removed lines found in diff."
            }

            guard let range = content.range(of: oldBlock) else {
                return "Error: Original block not found in file."
            }

            content.replaceSubrange(range, with: newBlock)
            try content.write(toFile: path, atomically: true, encoding: .utf8)

            return "Successfully applied patch to \(path)"
        } catch {
            return "Error applying patch: \(error.localizedDescription)"
        }
    }
}

//
//  WriteFile.swift
//  
//
//  Created by Ethan Brown on 3/20/26.
//

import Foundation

class WriteFile: PermissionAware {
    static let name = "write_file"

    private let toolDescription = """
        Writes content to a file at the specified path, creating parent \
        directories as needed. If the file already exists its ENTIRE content is \
        replaced — to modify part of an existing file, use replace_in_file \
        instead of rewriting the whole file.
        """

    func permissionRequests(args: [String : Any]) -> [PermissionRequest] {
        guard let path = args["path"] as? String, !path.isEmpty else { return [] }

        if FileManager.default.fileExists(atPath: path) {
            return [
                PermissionRequest(action: .write, target: path, requirement: .userApproval, reason: "Overwrite existing file at '\(path)' (all previous content will be replaced).")
            ]
        }

        return [
            PermissionRequest(action: .write, target: path)
        ]
    }

    private let parametersSchema: [String: Any] = [
        "type": "object",
        "required": ["path", "content"],
        "properties": [
            "path": [
                "type": "string",
                "description": "The full path of the file to write"
            ],
            "content": [
                "type": "string",
                "description": "The text content to write to the file"
            ]
        ]
    ]

    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": WriteFile.name,
            "description": toolDescription,
            "parameters": parametersSchema
        ]
    }

    func anthropicSchema() -> [String : Any] {
        return [
            "name": WriteFile.name,
            "description": toolDescription,
            "input_schema": parametersSchema
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": WriteFile.name,
                "description": toolDescription,
                "parameters": parametersSchema
            ]
        ]
    }

    func execute(args: [String : Any]) async -> String {
        guard let path = args["path"] as? String, !path.isEmpty else {
            return "Error: No path provided."
        }
        guard let content = args["content"] as? String else {
            return "Error: No content provided."
        }

        do {
            let fileURL = URL(fileURLWithPath: path)
            let existed = FileManager.default.fileExists(atPath: path)
            let previousSize = existed
                ? ((try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                : 0

            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            try content.write(to: fileURL, atomically: true, encoding: .utf8)

            let lineCount = content.components(separatedBy: .newlines).count
            if (existed) {
                return "Overwrote \(path) (was \(previousSize) bytes; now \(content.utf8.count) bytes, \(lineCount) lines). All previous content was replaced."
            }
            return "Created \(path) (\(content.utf8.count) bytes, \(lineCount) lines)."
        } catch let error {
            return "Error writing file at \(path): \(error.localizedDescription)"
        }
    }
}

//
//  ReplaceInFile.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/17/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

class ReplaceInFile: PermissionAware {
    static let name = "replace_in_file"

    private let toolDescription = """
        Replaces exact text in a file. The 'old' text must match the file content \
        EXACTLY, including whitespace and indentation, and must appear exactly once \
        in the file — include enough surrounding lines to make it unique. To replace \
        every occurrence intentionally, pass replace_all: true. Never include \
        line-number prefixes from read_file output in 'old'.
        """

    func permissionRequests(args: [String : Any]) -> [PermissionRequest] {
        guard let path = args["path"] as? String,
                !path.isEmpty else { return [] }
        guard let _ = args["old"] as? String else { return [] }
        guard let _ = args["new"] as? String else { return [] }

        return [
            PermissionRequest(action: .read, target: path),
            PermissionRequest(action: .write, target: path, requirement: .userApproval, reason: "Modify file at '\(path)'.")
        ]
    }

    private let parametersSchema: [String: Any] = [
        "type": "object",
        "required": ["path", "old", "new"],
        "properties": [
            "path": [
                "type": "string",
                "description": "The file to modify"
            ],
            "old": [
                "type": "string",
                "description": "The exact text to replace. Must match the file exactly (whitespace included) and be unique in the file unless replace_all is true."
            ],
            "new": [
                "type": "string",
                "description": "The replacement text"
            ],
            "replace_all": [
                "type": "boolean",
                "description": "Replace every occurrence instead of requiring uniqueness",
                "default": false
            ]
        ]
    ]

    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": ReplaceInFile.name,
            "description": toolDescription,
            "parameters": parametersSchema
        ]
    }

    func anthropicSchema() -> [String : Any] {
        return [
            "name": ReplaceInFile.name,
            "description": toolDescription,
            "input_schema": parametersSchema
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": ReplaceInFile.name,
                "description": toolDescription,
                "parameters": parametersSchema
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let path = args["path"] as? String, !path.isEmpty else {
            return "Error: No path provided."
        }

        guard let old = args["old"] as? String, !old.isEmpty else {
            return "Error: No old text provided."
        }

        guard let new = args["new"] as? String else {
            return "Error: No new text provided."
        }

        let replaceAll = args["replace_all"] as? Bool ?? false

        guard FileManager.default.fileExists(atPath: path) else {
            return "Error: File not found at '\(path)'. Use find_file to locate the correct path."
        }

        let original: String
        do {
            original = try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            return "Error: Could not read '\(path)' as UTF-8 text: \(error.localizedDescription)"
        }

        let occurrences = original.components(separatedBy: old).count - 1

        if (occurrences == 0) {
            return """
            Error: Target text not found in \(path). \
            The 'old' text must match the file content exactly, including whitespace \
            and indentation. Read the file (or the relevant line range) again — the \
            current content may differ from what you expect — then retry with the \
            exact text.
            """
        }

        if (occurrences > 1 && !replaceAll) {
            return """
            Error: Target text appears \(occurrences) times in \(path); refusing an \
            ambiguous edit. Include more surrounding context in 'old' to make it \
            unique, or pass replace_all: true to intentionally replace all \
            \(occurrences) occurrences.
            """
        }

        do {
            if (replaceAll && occurrences > 1) {
                let updated = original.replacingOccurrences(of: old, with: new)
                try updated.write(toFile: path, atomically: true, encoding: .utf8)
                return "Replaced \(occurrences) occurrences in \(path)."
            }

            guard let range = original.range(of: old) else {
                return "Error: Target text not found."
            }

            let lineNumber = original[..<range.lowerBound].filter { $0 == "\n" }.count + 1
            let updated = original.replacingCharacters(in: range, with: new)
            try updated.write(toFile: path, atomically: true, encoding: .utf8)

            return "Replaced 1 occurrence at line \(lineNumber) in \(path)."
        } catch {
            return "Error replacing text: \(error.localizedDescription)"
        }
    }
}

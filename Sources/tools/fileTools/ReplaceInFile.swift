//
//  ReplaceInFile.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/17/26.
//

import Foundation

class ReplaceInFile: ChatSessionAware {
    let name = "replace_in_file"
    private var session: ChatSessionInfo?

    func setSession(_ session: ChatSessionInfo) {
        self.session = session
    }

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Replaces the first occurrence of exact text in a file.",
                "parameters": [
                    "type": "object",
                    "required": ["path", "old", "new"],
                    "properties": [
                        "path": [
                            "type": "string",
                            "description": "The file to modify"
                        ],
                        "old": [
                            "type": "string",
                            "description": "The exact text to replace"
                        ],
                        "new": [
                            "type": "string",
                            "description": "The replacement text"
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

        guard let old = args["old"] as? String else {
            return "Error: No old text provided."
        }

        guard let new = args["new"] as? String else {
            return "Error: No new text provided."
        }

        guard let session = session else {
            return "Invalid chat session. Developer error."
        }
        
        do {
            try ToolPermissionGuard.guardRead(from: path, session: session)
            try ToolPermissionGuard.guardWrite(to: path, session: session)
        } catch {
            return String(describing: error)
        }

        do {
            let original = try String(contentsOfFile: path, encoding: .utf8)

            guard let range = original.range(of: old) else {
                return "Error: Target text not found."
            }

            let updated = original.replacingCharacters(in: range, with: new)
            try updated.write(toFile: path, atomically: true, encoding: .utf8)

            return "Successfully replaced text in \(path)"
        } catch {
            return "Error replacing text: \(error.localizedDescription)"
        }
    }
}

//
//  ReplaceInFile.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/17/26.
//

import Foundation

class ReplaceInFile: PermissionAware {
    let name = "replace_in_file"
    
    func permissionRequests(args: [String : Any]) -> [PermissionRequest] {
        guard let path = args["path"] as? String,
                !path.isEmpty else { return [] }
        guard let old = args["old"] as? String else { return [] }
        guard let new = args["new"] as? String else { return [] }
        
        return [
            PermissionRequest(action: .read, target: path),
            PermissionRequest(action: .write, target: path, requirement: .userApproval, reason: "Modify file at '\(path)'.")
        ]
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

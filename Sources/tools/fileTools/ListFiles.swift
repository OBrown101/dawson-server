//
//  ListFiles.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/17/26.
//

import Foundation

class ListFiles: ChatSessionAware {
    let name = "list_files"
    private var session: ChatSessionInfo?

    func setSession(_ session: ChatSessionInfo) {
        self.session = session
    }

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Recursively lists files and directories under the specified path. Returns relative paths for token efficiency.",
                "parameters": [
                    "type": "object",
                    "required": ["path"],
                    "properties": [
                        "path": [
                            "type": "string",
                            "description": "The root directory to list"
                        ],
                        "include_hidden": [
                            "type": "boolean",
                            "description": "Whether to include hidden files and directories",
                            "default": false
                        ],
                        "max_results": [
                            "type": "integer",
                            "description": "Maximum number of results to return",
                            "default": 1000
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

        let includeHidden = args["include_hidden"] as? Bool ?? false
        let maxResults = max(1, args["max_results"] as? Int ?? 1000)

        guard let session = session else {
            return "Invalid chat session. Developer error."
        }
        
        do {
            try ToolPermissionGuard.guardRead(from: path, session: session)
        } catch {
            return String(describing: error)
        }

        do {
            let rootURL = URL(fileURLWithPath: path)
            let values = try rootURL.resourceValues(forKeys: [.isDirectoryKey])

            guard values.isDirectory == true else {
                return "Error: Path is not a directory."
            }

            guard let enumerator = FileManager.default.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
                options: [.skipsPackageDescendants]
            ) else {
                return "Error: Unable to enumerate directory."
            }

            var results: [String] = []
            while let item = enumerator.nextObject() as? URL {
                let fileValues = try item.resourceValues(forKeys: [.isHiddenKey])

                if !includeHidden && (fileValues.isHidden ?? false) {
                    continue
                }

                let relativePath = item.path.replacingOccurrences(of: rootURL.path + "/", with: "")
                results.append(relativePath)

                if results.count >= maxResults {
                    break
                }
            }

            if results.isEmpty {
                return "No files found."
            }

            return results.joined(separator: "")
        } catch {
            return "Error listing files: \(error.localizedDescription)"
        }
    }
}

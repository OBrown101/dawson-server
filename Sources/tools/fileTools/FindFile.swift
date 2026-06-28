//
//  FindFile.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/26/26.
//

import Foundation

class FindFile: PermissionAware {
    let name = "find_file"
    let description = "Finds files or directories by name under a root path. Use this when looking for filenames or directory names such as README.md, *.kt, build.gradle.kts, App.swift, or ViewModel.kt. This does not search file contents. Returns absolute paths."

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
                "required": ["path", "pattern"],
                "properties": [
                    "path": [
                        "type": "string",
                        "description": "The root directory to search"
                    ],
                    "pattern": [
                        "type": "string",
                        "description": "Filename or directory name pattern to search for. Supports simple wildcard *."
                    ],
                    "include_directories": [
                        "type": "boolean",
                        "description": "Whether to include directories in results",
                        "default": false
                    ],
                    "case_sensitive": [
                        "type": "boolean",
                        "description": "Whether matching is case sensitive",
                        "default": false
                    ],
                    "include_hidden": [
                        "type": "boolean",
                        "description": "Whether to include hidden files and directories",
                        "default": false
                    ],
                    "max_results": [
                        "type": "integer",
                        "description": "Maximum number of results to return",
                        "default": 100
                    ]
                ]
            ]
        ]
    }

    func anthropicSchema() -> [String : Any] {
        return [
            "name": name,
            "description": description,
            "input_schema": openAISchema()["parameters"] as? [String : Any] ?? [:]
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": openAISchema()["parameters"] as? [String : Any] ?? [:]
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let path = args["path"] as? String, !path.isEmpty else {
            return "Error: No path provided."
        }

        guard let pattern = args["pattern"] as? String, !pattern.isEmpty else {
            return "Error: No pattern provided."
        }

        let includeDirectories = args["include_directories"] as? Bool ?? false
        let caseSensitive = args["case_sensitive"] as? Bool ?? false
        let includeHidden = args["include_hidden"] as? Bool ?? false
        let maxResults = max(1, args["max_results"] as? Int ?? 100)

        do {
            let rootURL = URL(fileURLWithPath: path)
            let rootValues = try rootURL.resourceValues(forKeys: [.isDirectoryKey])

            guard rootValues.isDirectory == true else {
                return "Error: Path is not a directory."
            }

            guard let enumerator = FileManager.default.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
                options: [.skipsPackageDescendants]
            ) else {
                return "Error: Unable to enumerate directory."
            }

            let regex = try regexFromWildcard(pattern, caseSensitive: caseSensitive)
            var results: [String] = []

            while let item = enumerator.nextObject() as? URL {
                let values = try item.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey])

                if (!includeHidden && (values.isHidden ?? false)) {
                    if (values.isDirectory == true) {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                if ((values.isDirectory == true) && !includeDirectories) { continue }

                let name = item.lastPathComponent
                let range = NSRange(name.startIndex..<name.endIndex, in: name)

                if regex.firstMatch(in: name, range: range) != nil {
                    results.append(item.path)

                    if (results.count >= maxResults) { break }
                }
            }

            if (results.isEmpty) {
                return "No matching files found."
            }

            return results.joined(separator: "\n")
        } catch {
            return "Error finding files: \(error.localizedDescription)"
        }
    }

    private func regexFromWildcard(_ pattern: String, caseSensitive: Bool) throws -> NSRegularExpression {
        let escaped = NSRegularExpression.escapedPattern(for: pattern).replacingOccurrences(of: "\\*", with: ".*")

        let regexPattern = "^\(escaped)$"
        let options: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]

        return try NSRegularExpression(pattern: regexPattern, options: options)
    }
}

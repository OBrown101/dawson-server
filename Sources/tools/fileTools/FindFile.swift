//
//  FindFile.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/26/26.
//

import Foundation

class FindFile: PermissionAware {
    static let name = "find_file"
    let description = "Finds files or directories by name under a root path. Use this when looking for filenames or directory names such as README.md, *.kt, build.gradle.kts, App.swift, or ViewModel.kt. The pattern must match the WHOLE name (use * wildcards for partial matches, e.g. *Handler*). This does not search file contents — use grep_search for that. Returns absolute paths. Skips common build/dependency directories (.git, node_modules, build, etc.) by default."

    private static let defaultMaxResults = 50
    private static let hardMaxResults = 200

    private let defaultExcludedDirectories: Set<String> = [
        ".git", ".build", "build", "DerivedData", "node_modules", ".gradle", ".idea", ".swiftpm"
    ]

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
            "name": FindFile.name,
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
                        "description": "Filename or directory name pattern. Matches the whole name; supports * wildcards (e.g. *.swift, *ViewModel*)."
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
                        "description": "Maximum number of results to return (up to \(FindFile.hardMaxResults))",
                        "default": FindFile.defaultMaxResults
                    ]
                ]
            ]
        ]
    }

    func anthropicSchema() -> [String : Any] {
        return [
            "name": FindFile.name,
            "description": description,
            "input_schema": openAISchema()["parameters"] as? [String : Any] ?? [:]
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": FindFile.name,
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
        let maxResults = min(FindFile.hardMaxResults, max(1, args["max_results"] as? Int ?? FindFile.defaultMaxResults))

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
            var totalMatches = 0

            while let item = enumerator.nextObject() as? URL {
                let values = try item.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey])
                let name = item.lastPathComponent

                if (values.isDirectory == true && defaultExcludedDirectories.contains(name)) {
                    enumerator.skipDescendants()
                    continue
                }

                if (!includeHidden && (values.isHidden ?? false)) {
                    if (values.isDirectory == true) {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                if ((values.isDirectory == true) && !includeDirectories) { continue }

                let range = NSRange(name.startIndex..<name.endIndex, in: name)

                if regex.firstMatch(in: name, range: range) != nil {
                    totalMatches += 1
                    if results.count < maxResults {
                        results.append(item.path)
                    }

                    if (results.count >= maxResults) { break }
                }
            }

            if results.isEmpty {
                return "No files matching '\(pattern)' found under \(rootURL.path). The pattern must match the whole name — try a broader wildcard pattern like *\(pattern)* or search a higher-level directory."
            }

            let truncated = totalMatches > maxResults ? "\n(Showing \(maxResults) of \(totalMatches)+ results. Narrow your search pattern.)" : ""
            return results.joined(separator: "\n") + truncated
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

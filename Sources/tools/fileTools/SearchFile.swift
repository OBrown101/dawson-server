//
//  SearchFile.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/17/26.
//

import Foundation

class SearchFile: PermissionAware {
    let name = "search_file"
    let description = "Searches inside file contents for exact text and returns matching absolute file paths with line numbers. Use find_file instead when looking for filenames or directory names. Required parameters: path and pattern."
    
    private let maxSearchResults = 50
    
    func permissionRequests(args: [String : Any]) -> [PermissionRequest] {
        guard let pattern = args["pattern"] as? String,
              !pattern.isEmpty else { return [] }
        guard let path = args["path"] as? String,
              !path.isEmpty else { return [] }
        
        return [PermissionRequest(action: .read, target: path)]
    }
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": name,
            "description": description,
            "parameters": [
                "type": "object",
                "required": ["pattern", "path"],
                "properties": [
                    "pattern": [
                        "type": "string",
                        "description": "The text content to search for inside files. Not a filename pattern."
                    ],
                    "path": [
                        "type": "string",
                        "description": "The root directory or file to search"
                    ],
                    "case_sensitive": [
                        "type": "boolean",
                        "description": "Whether search is case sensitive",
                        "default": false
                    ],
                    "max_results": [
                        "type": "integer",
                        "description": "Maximum number of matches to return",
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
            "input_schema": [
                "type": "object",
                "required": ["pattern", "path"],
                "properties": [
                    "pattern": [
                        "type": "string",
                        "description": "The text content to search for inside files. Not a filename pattern."
                    ],
                    "path": [
                        "type": "string",
                        "description": "The root directory or file to search"
                    ],
                    "case_sensitive": [
                        "type": "boolean",
                        "description": "Whether search is case sensitive",
                        "default": false
                    ],
                    "max_results": [
                        "type": "integer",
                        "description": "Maximum number of matches to return",
                        "default": 100
                    ]
                ]
            ]
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "required": ["pattern", "path"],
                    "properties": [
                        "pattern": [
                            "type": "string",
                            "description": "The text content to search for inside files. Not a filename pattern."
                        ],
                        "path": [
                            "type": "string",
                            "description": "The root directory or file to search"
                        ],
                        "case_sensitive": [
                            "type": "boolean",
                            "description": "Whether search is case sensitive",
                            "default": false
                        ],
                        "max_results": [
                            "type": "integer",
                            "description": "Maximum number of matches to return",
                            "default": 100
                        ]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let pattern = args["pattern"] as? String, !pattern.isEmpty else {
            return "Error: No pattern provided."
        }

        guard let path = args["path"] as? String, !path.isEmpty else {
            return "Error: No path provided."
        }

        let caseSensitive = args["case_sensitive"] as? Bool ?? false
        let maxResults = min(maxSearchResults, max(1, args["max_results"] as? Int ?? maxSearchResults))
        
        do {
            let rootURL = URL(fileURLWithPath: path)
            let rootValues = try rootURL.resourceValues(forKeys: [.isDirectoryKey])
            let files: [URL]

            if (rootValues.isDirectory == true) {
                guard let enumerator = FileManager.default.enumerator(
                    at: rootURL,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else {
                    return "Error: Unable to enumerate directory."
                }

                files = enumerator.compactMap { item in
                    guard let url = item as? URL else { return nil }
                    let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
                    return values?.isRegularFile == true ? url : nil
                }
            } else {
                files = [rootURL]
            }

            var results: [String] = []
            var totalMatches = 0
            let compareOptions: String.CompareOptions = caseSensitive ? [] : [.caseInsensitive]

            outerLoop: for fileURL in files {
                guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
                    continue
                }

                let lines = text.components(separatedBy: .newlines)

                for (index, line) in lines.enumerated() {
                    if (line.range(of: pattern, options: compareOptions) != nil) {
                        totalMatches += 1
                        if (results.count < maxResults) {
                            let trimmed = line.trimmingCharacters(in: .whitespaces)
                            results.append("\(fileURL.path):\(index + 1): \(trimmed)")
                        }

                        if (results.count >= maxResults) {
                            break outerLoop
                        }
                    }
                }
            }

            if (results.isEmpty) {
                return "No matches found."
            }

            return results.joined(separator: "\n")
        } catch {
            return "Error searching files: \(error.localizedDescription)"
        }
    }
}

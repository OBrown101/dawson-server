//
//  SearchFile.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/17/26.
//

import Foundation

class SearchFile: ChatSessionAware {
    let name = "search_file"
    private var session: ChatSessionInfo?

    func setSession(_ session: ChatSessionInfo) {
        self.session = session
    }

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Searches recursively for text within files and returns matching lines with file paths and line numbers.",
                "parameters": [
                    "type": "object",
                    "required": ["pattern", "path"],
                    "properties": [
                        "pattern": [
                            "type": "string",
                            "description": "The text to search for"
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
        let maxResults = max(1, args["max_results"] as? Int ?? 100)

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
            let compareOptions: String.CompareOptions = caseSensitive ? [] : [.caseInsensitive]

            outerLoop: for fileURL in files {
                guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
                    continue
                }

                let relativePath = (rootValues.isDirectory == true)
                    ? fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")
                    : fileURL.lastPathComponent

                let lines = text.components(separatedBy: .newlines)

                for (index, line) in lines.enumerated() {
                    if line.range(of: pattern, options: compareOptions) != nil {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        results.append("\(relativePath):\(index + 1): \(trimmed)")

                        if results.count >= maxResults {
                            break outerLoop
                        }
                    }
                }
            }

            if (results.isEmpty) {
                return "No matches found."
            }

            return results.joined(separator: "")
        } catch {
            return "Error searching files: \(error.localizedDescription)"
        }
    }
}

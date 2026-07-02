//
//  Grep.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/1/26.
//

import Foundation

final class Grep: PermissionAware {
    let name = "grep_search"
    let description = "Safely searches inside text files under a permitted file or directory. Returns matching lines with absolute file paths and line numbers. Use find_file when searching filenames instead."

    private static let defaultMaxResults = 100
    private static let hardMaxResults = 1000
    private static let maxFileSize = 1_000_000

    private let defaultExcludedDirectories: Set<String> = [
        ".git", ".build", "build", "DerivedData", "node_modules", ".gradle", ".idea", ".swiftpm"
    ]

    func permissionRequests(args: [String : Any]) -> [PermissionRequest] {
        guard let path = args["path"] as? String,
                (!path.isEmpty),
              let pattern = args["pattern"] as? String,
                (!pattern.isEmpty) else { return [] }

        return [PermissionRequest(action: .read, target: path)]
    }

    let parametersSchema: [String: Any] =
        [
            "type": "object",
            "required": ["path", "pattern"],
            "properties": [
                "path": [
                    "type": "string",
                    "description": "The file or root directory to search"
                ],
                "pattern": [
                    "type": "string",
                    "description": "Text or regex pattern to search for inside files"
                ],
                "regex": [
                    "type": "boolean",
                    "description": "Whether pattern should be treated as a regular expression",
                    "default": false
                ],
                "case_sensitive": [
                    "type": "boolean",
                    "description": "Whether search is case sensitive",
                    "default": false
                ],
                "extensions": [
                    "type": "array",
                    "description": "Optional file extensions to include, such as [\"swift\", \"kt\"]",
                    "items": ["type": "string"]
                ],
                "exclude_directories": [
                    "type": "array",
                    "description": "Directory names to skip",
                    "items": ["type": "string"]
                ],
                "include_hidden": [
                    "type": "boolean",
                    "description": "Whether to include hidden files and directories",
                    "default": false
                ],
                "max_results": [
                    "type": "integer",
                    "description": "Maximum number of matching lines to return",
                    "default": defaultMaxResults
                ]
            ]
        ]
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": name,
            "description": description,
            "parameters": parametersSchema
        ]
    }

    func anthropicSchema() -> [String : Any] {
        return [
            "name": name,
            "description": description,
            "input_schema": parametersSchema
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": parametersSchema
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let path = args["path"] as? String,
                (!path.isEmpty) else { return "Error: No path provided." }

        guard let pattern = args["pattern"] as? String,
                (!pattern.isEmpty) else { return "Error: No pattern provided." }

        let caseSensitive = args["case_sensitive"] as? Bool ?? false
        let includeHidden = args["include_hidden"] as? Bool ?? false
        let useRegex = args["regex"] as? Bool ?? false
        let maxResults = min(Grep.hardMaxResults, max(1, args["max_results"] as? Int ?? Grep.defaultMaxResults))
        let extensions = normalizedExtensions(args["extensions"] as? [String])
        let excludedDirectories = normalizedExcludedDirectories(args["exclude_directories"] as? [String])

        let rootURL = URL(fileURLWithPath: path).standardizedFileURL

        do {
            let rootValues = try rootURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            let files: [URL]

            if rootValues.isRegularFile == true {
                files = [rootURL]
            } else if rootValues.isDirectory == true {
                files = try collectFiles(
                    rootURL: rootURL,
                    includeHidden: includeHidden,
                    extensions: extensions,
                    excludedDirectories: excludedDirectories
                )
            } else {
                return "Error: Path is not a file or directory."
            }

            let regex = try makeRegex(pattern: pattern, useRegex: useRegex, caseSensitive: caseSensitive)
            var matches: [String] = []
            var searchedFiles = 0
            var skippedFiles = 0

            for fileURL in files {
                guard (matches.count < maxResults) else { break }

                if shouldSkipFile(fileURL, extensions: extensions, includeHidden: includeHidden) {
                    skippedFiles += 1
                    continue
                }

                let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                if (fileSize > Grep.maxFileSize) {
                    skippedFiles += 1
                    continue
                }

                guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
                    skippedFiles += 1
                    continue
                }

                searchedFiles += 1
                let lines = text.components(separatedBy: .newlines)

                for (index, line) in lines.enumerated() {
                    guard (matches.count < maxResults) else { break }

                    let range = NSRange(line.startIndex..<line.endIndex, in: line)
                    if (regex.firstMatch(in: line, range: range) != nil) {
                        matches.append("\(fileURL.path):\(index + 1): \(line)")
                    }
                }
            }

            if (matches.isEmpty) {
                return """
                No matches found.

                Pattern: \(pattern)
                Path: \(rootURL.path)
                Files searched: \(searchedFiles)
                Files skipped: \(skippedFiles)
                """
            }

            var output = """
            Matches for "\(pattern)"
            Path: \(rootURL.path)
            Files searched: \(searchedFiles)
            Files skipped: \(skippedFiles)

            \(matches.joined(separator: "\n"))
            """

            if (matches.count >= maxResults) {
                output += "\n\nResult truncated after \(maxResults) matches. Increase max_results or narrow the search."
            }

            return output
        } catch {
            return "Error searching files: \(error.localizedDescription)"
        }
    }

    private func collectFiles(
        rootURL: URL,
        includeHidden: Bool,
        extensions: Set<String>?,
        excludedDirectories: Set<String>
    ) throws -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey]
        let options: FileManager.DirectoryEnumerationOptions = includeHidden
            ? [.skipsPackageDescendants]
            : [.skipsHiddenFiles, .skipsPackageDescendants]

        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: options
        ) else { return [] }

        var files: [URL] = []

        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
            let name = url.lastPathComponent

            if (values.isSymbolicLink == true) {
                if values.isDirectory == true {
                    enumerator.skipDescendants()
                }
                continue
            }

            if (values.isDirectory == true) {
                if excludedDirectories.contains(name) {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard (values.isRegularFile == true) else { continue }

            if let extensions = extensions,
               (!extensions.contains(url.pathExtension.lowercased())) { continue }

            files.append(url)
        }

        return files
    }

    private func shouldSkipFile(_ url: URL, extensions: Set<String>?, includeHidden: Bool) -> Bool {
        if (!includeHidden && url.lastPathComponent.hasPrefix(".")),
           let extensions = extensions,
           (!extensions.contains(url.pathExtension.lowercased())) { return true }

        return false
    }

    private func makeRegex(pattern: String, useRegex: Bool, caseSensitive: Bool) throws -> NSRegularExpression {
        let finalPattern = useRegex ? pattern : NSRegularExpression.escapedPattern(for: pattern)
        let options: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
        return try NSRegularExpression(pattern: finalPattern, options: options)
    }

    private func normalizedExtensions(_ rawExtensions: [String]?) -> Set<String>? {
        guard let rawExtensions = rawExtensions,
              (!rawExtensions.isEmpty) else { return nil }

        let normalized = rawExtensions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .map { $0.hasPrefix(".") ? String($0.dropFirst()) : $0 }
            .filter { !$0.isEmpty }

        return (normalized.isEmpty) ? nil : Set(normalized)
    }

    private func normalizedExcludedDirectories(_ rawDirectories: [String]?) -> Set<String> {
        guard let rawDirectories = rawDirectories,
                (!rawDirectories.isEmpty) else { return defaultExcludedDirectories }

        let normalized = rawDirectories
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return Set(normalized)
    }
}

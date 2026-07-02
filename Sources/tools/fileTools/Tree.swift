//
//  Tree.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/1/26.
//

import Foundation

final class Tree: PermissionAware {
    let name = "tree"
    let description = "Shows a compact directory tree for a known directory. Use this to understand project structure without listing every file recursively."

    private static let defaultMaxEntries = 300
    private static let hardMaxEntries = 1000
    private static let defaultDepth = 3
    private static let hardMaxDepth = 8

    func permissionRequests(args: [String : Any]) -> [PermissionRequest] {
        guard let path = args["path"] as? String, !path.isEmpty else { return [] }
        return [PermissionRequest(action: .read, target: path)]
    }
    
    let parametersSchema: [String: Any] =
        [
            "type": "object",
            "required": ["path"],
            "properties": [
                "path": [
                    "type": "string",
                    "description": "The root directory to display"
                ],
                "max_depth": [
                    "type": "integer",
                    "description": "Maximum directory depth to display",
                    "default": defaultDepth
                ],
                "max_entries": [
                    "type": "integer",
                    "description": "Maximum number of files/directories to display",
                    "default": defaultMaxEntries
                ],
                "include_hidden": [
                    "type": "boolean",
                    "description": "Whether to include hidden files and directories",
                    "default": false
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

        let includeHidden = args["include_hidden"] as? Bool ?? false
        let maxDepth = min(Tree.hardMaxDepth, max(1, args["max_depth"] as? Int ?? Tree.defaultDepth))
        let maxEntries = min(Tree.hardMaxEntries, max(1, args["max_entries"] as? Int ?? Tree.defaultMaxEntries))

        let rootURL = URL(fileURLWithPath: path).standardizedFileURL

        do {
            let values = try rootURL.resourceValues(forKeys: [.isDirectoryKey])
            guard (values.isDirectory == true) else {
                return "Error: Path is not a directory."
            }

            var lines: [String] = [rootURL.lastPathComponent + "/"]
            var entryCount = 0
            var wasTruncated = false

            try buildTree(
                url: rootURL,
                prefix: "",
                depth: 1,
                maxDepth: maxDepth,
                maxEntries: maxEntries,
                includeHidden: includeHidden,
                entryCount: &entryCount,
                wasTruncated: &wasTruncated,
                lines: &lines
            )

            var output = lines.joined(separator: "\n")
            if (wasTruncated) {
                output += "\n\nResult truncated after \(maxEntries) entries. Increase max_entries or narrow the path."
            }

            return output
        } catch {
            return "Error building tree: \(error.localizedDescription)"
        }
    }

    private func buildTree(
        url: URL,
        prefix: String,
        depth: Int,
        maxDepth: Int,
        maxEntries: Int,
        includeHidden: Bool,
        entryCount: inout Int,
        wasTruncated: inout Bool,
        lines: inout [String]
    ) throws {
        guard (depth <= maxDepth) else { return }
        guard (entryCount < maxEntries) else {
            wasTruncated = true
            return
        }

        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
        let children = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: includeHidden ? [] : [.skipsHiddenFiles]
        )
        .filter { includeHidden || !$0.lastPathComponent.hasPrefix(".") }
        .sorted { left, right in
            let leftIsDirectory = (try? left.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let rightIsDirectory = (try? right.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

            if (leftIsDirectory != rightIsDirectory) {
                return (leftIsDirectory && !rightIsDirectory)
            }

            return (left.lastPathComponent.localizedCaseInsensitiveCompare(right.lastPathComponent) == .orderedAscending)
        }

        for (index, child) in children.enumerated() {
            guard (entryCount < maxEntries) else {
                wasTruncated = true
                return
            }

            let values = try child.resourceValues(forKeys: keys)
            let isDirectory = values.isDirectory == true
            let isSymlink = values.isSymbolicLink == true
            let isLast = index == children.count - 1

            let connector = (isLast) ? "└── " : "├── "
            let nextPrefix = prefix + ((isLast) ? "    " : "│   ")

            var name = child.lastPathComponent
            if (isDirectory) { name += "/" }
            if (isSymlink) { name += " -> [symlink skipped]" }

            lines.append(prefix + connector + name)
            entryCount += 1

            if (isDirectory && !isSymlink) {
                try buildTree(
                    url: child,
                    prefix: nextPrefix,
                    depth: (depth + 1),
                    maxDepth: maxDepth,
                    maxEntries: maxEntries,
                    includeHidden: includeHidden,
                    entryCount: &entryCount,
                    wasTruncated: &wasTruncated,
                    lines: &lines
                )
            }
        }
    }
}

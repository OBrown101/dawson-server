//
//  Utility.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

class FileUtilities {
    
    static func inSessionDirectories(path: String, directories: [String]) -> Bool {
        let fileURL = canonicalFileURL(path)

        return directories.contains { directory in
            let directoryURL = canonicalFileURL(directory)

            return isSameOrChild(fileURL, of: directoryURL) || (fileURL == directoryURL)
        }
    }
    
    static func canonicalFilePath(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    }

    private static func canonicalFileURL(_ path: String) -> URL {
        let normalizedPath = normalizePathString(path)

        let url: URL
        if let parsedURL = URL(string: normalizedPath),
           parsedURL.isFileURL {
            url = parsedURL
        } else {
            url = URL(fileURLWithPath: normalizedPath)
        }

        if FileManager.default.fileExists(atPath: url.path) {
            return url.standardizedFileURL.resolvingSymlinksInPath()
        }
        return url.standardizedFileURL
    }

    private static func normalizePathString(_ path: String) -> String {
        var result = path.trimmingCharacters(in: .whitespacesAndNewlines)

        if result.hasPrefix("\""), result.hasSuffix("\""), result.count >= 2 {
            result.removeFirst()
            result.removeLast()
        }

        if result.hasPrefix("'"), result.hasSuffix("'"), result.count >= 2 {
            result.removeFirst()
            result.removeLast()
        }

        result = NSString(string: result).expandingTildeInPath

        // Handles shell-escaped raw paths like --> /Users/me/Jims\ Files\ Local/file.sql
        result = result.replacingOccurrences(of: #"\\ "#, with: " ", options: .regularExpression)

        return result
    }

    private static func isSameOrChild(_ fileURL: URL, of directoryURL: URL) -> Bool {
        let fileComponents = fileURL.pathComponents
        let directoryComponents = directoryURL.pathComponents

        guard fileComponents.count >= directoryComponents.count else {
            return false
        }

        return Array(fileComponents.prefix(directoryComponents.count)) == directoryComponents
    }
}

//
//  WebProvenance.swift
//  DAWSON
//
//  Created by Ethan Brown on 11/8/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

final class WebProvenance: @unchecked Sendable {

    static let shared = WebProvenance()

    private var seenURLs: [String: Set<String>] = [:]   // agentUUID → normalized URLs
    private let lock = NSLock()

    func record(_ urlString: String, agentUUID: String) {
        guard let normalized = WebProvenance.normalize(urlString) else { return }
        lock.lock()
        defer { lock.unlock() }
        seenURLs[agentUUID, default: []].insert(normalized)
    }

    func recordURLs(in text: String, agentUUID: String) {
        for url in WebProvenance.extractURLs(from: text) {
            record(url, agentUUID: agentUUID)
        }
    }

    func contains(_ urlString: String, agentUUID: String) -> Bool {
        guard let normalized = WebProvenance.normalize(urlString) else { return false }
        lock.lock()
        defer { lock.unlock() }
        return seenURLs[agentUUID]?.contains(normalized) ?? false
    }

    static func normalize(_ urlString: String) -> String? {
        // Trim whitespace, lowercase scheme+host, drop the fragment, treat
        // empty path as "/" (prevents forcing approvals for trivial mishaps)
        // Path and query are compared exactly.

        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              let host = components.host?.lowercased(),
                (!host.isEmpty) else {
            return nil
        }
        components.scheme = scheme
        components.host = host
        components.fragment = nil
        if (components.path.isEmpty) {
            components.path = "/"
        }
        return components.string
    }

    static func extractURLs(from text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"https?://[^\s<>"'⟦⟧)\]]+"#, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let r = Range(match.range, in: text) else { return nil }
            // Shed trailing prose punctuation ("see https://x.com/y.").
            return String(text[r]).trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
        }
    }
}

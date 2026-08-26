//
//  SkillHandler.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/20/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

class SkillHandler: @unchecked Sendable {
    static let shared = SkillHandler()
    
    func loadSkills() -> [SkillMetadata] {
        let fileManager = FileManager.default
        
        let skillsRoot = DAWSON.databank
            .appendingPathComponent("skills")
        
        var skills: [SkillMetadata] = []
        
        guard let subdirectories = try? fileManager.contentsOfDirectory(at: skillsRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            print("Skills directory not found: \(skillsRoot.path)")
            return []
        }
        
        for directoryURL in subdirectories {
            // Ensure this is a directory
            guard let values = try? directoryURL.resourceValues(forKeys: [.isDirectoryKey]),
                (values.isDirectory == true) else { continue }
            
            let skillFileURL = directoryURL.appendingPathComponent("SKILL.md")
            
            // Ensure SKILL.md exists
            guard fileManager.fileExists(atPath: skillFileURL.path) else { continue }
            
            // Read file contents
            guard let content = try? String(contentsOf: skillFileURL, encoding: .utf8) else {
                print("Failed to read skill file: \(skillFileURL.path)")
                continue
            }
            
            // Parse YAML frontmatter
            guard let metadata = parseMetadata(content: content, directoryPath: directoryURL.path) else {
                print("Failed to parse skill metadata: \(skillFileURL.path)")
                continue
            }
            
            skills.append(metadata)
        }
        
        // Stable ordering helps reduce prompt churn
        return skills.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}

extension SkillHandler {
    private func parseMetadata(content: String, directoryPath: String) -> SkillMetadata? {
        guard let fields = frontmatterFields(content) else { return nil }
        
        guard
            let skillName = fields["name"],
            let skillDescription = fields["description"],
            !skillName.isEmpty,
            !skillDescription.isEmpty
        else {
            return nil
        }
        
        return SkillMetadata(
            name: skillName,
            description: skillDescription,
            directoryPath: directoryPath
        )
    }
    func frontmatterFields(_ content: String) -> [String: String]? {
        /// Pragmatic YAML frontmatter parser covering the shapes real (Claude-style) skills use:
        ///   key: value                      plain scalar
        ///   key: "value" / 'value'      quoted scalar
        ///   key: >- (or >, >+)           folded block  → lines joined with spaces
        ///   key: |- (or |, |+)               literal block → lines joined with newlines
        ///   key: value                      plain multi-line: indented continuation
        ///        wrapped continuation...      lines are folded into the value
        ///   # comment lines, blank lines, unknown keys, and nested structures
        ///   under unknown keys are skipped without derailing known keys.
        /// Frontmatter must start at line 1 with --- and closes at --- or ...
        
        let lines = content.components(separatedBy: .newlines)

        guard (trimmed(lines.first ?? "") == "---") else { return nil }

        // Find the closing delimiter
        var end = -1
        for index in 1..<lines.count {
            let line = trimmed(lines[index])
            if ((line == "---") || (line == "...")) {
                end = index
                break
            }
        }
        guard (end > 1) else { return nil }

        var fields: [String: String] = [:]
        var i = 1

        while (i < end) {
            let raw = lines[i]
            let line = trimmed(raw)

            // Blank lines, comments, and indented lines (content of an
            // unknown key's block/nested map) — skip.
            if (line.isEmpty || line.hasPrefix("#") || isIndented(raw)) {
                i += 1
                continue
            }

            // Top-level "key: ..." — anything else is malformed; skip it.
            guard let colonIndex = raw.firstIndex(of: ":") else {
                i += 1
                continue
            }

            let key = trimmed(String(raw[raw.startIndex..<colonIndex])).lowercased()
            var value = trimmed(String(raw[raw.index(after: colonIndex)...]))

            // Strip a trailing comment from unquoted scalars (" # ...")
            if !value.hasPrefix("\""),
               !value.hasPrefix("'"),
               let commentRange = value.range(of: " #") {
                value = trimmed(String(value[value.startIndex..<commentRange.lowerBound]))
            }

            if (isBlockIndicator(value)) {
                // Folded (>) or literal (|) block: consume indented lines
                let folded = value.hasPrefix(">")
                var block: [String] = []
                var j = i + 1
                while (j < end) {
                    let blockRaw = lines[j]
                    let blockLine = trimmed(blockRaw)
                    if (blockLine.isEmpty) {
                        block.append("")
                        j += 1
                        continue
                    }
                    guard (isIndented(blockRaw)) else { break }
                    block.append(blockLine)
                    j += 1
                }
                while (block.last?.isEmpty == true) {
                    block.removeLast()
                }
                value = (folded) ? block.filter { !$0.isEmpty }.joined(separator: " ") : block.joined(separator: "\n")
                i = j
            } else {
                value = unquote(value)

                // Plain multi-line: indented continuation lines fold in.
                // (Also covers "key:" on its own line with indented content.)
                var j = i + 1
                while (j < end) {
                    let contRaw = lines[j]
                    let contLine = trimmed(contRaw)
                    if contLine.isEmpty { break }
                    guard isIndented(contRaw),
                            !contLine.hasPrefix("#") else { break }
                    value = (value.isEmpty) ? contLine : (value + " " + contLine)
                    j += 1
                }
                i = j
            }

            if (!key.isEmpty) {
                fields[key] = value
            }
        }

        return fields
    }
}

extension SkillHandler {
    
    private func isBlockIndicator(_ value: String) -> Bool {
        return ["|", "|-", "|+", ">", ">-", ">+"].contains(value)
    }

    private func isIndented(_ raw: String) -> Bool {
        return raw.hasPrefix(" ") || raw.hasPrefix("\t")
    }

    private func trimmed(_ string: String) -> String {
        return string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func unquote(_ value: String) -> String {
        // Removes matching single or double quotes if present.
        var result = value
        if (result.hasPrefix("\"") && result.hasSuffix("\"") && (result.count >= 2)) ||
           (result.hasPrefix("'") && result.hasSuffix("'") && (result.count >= 2)) {
            result.removeFirst()
            result.removeLast()
        }
        return result
    }
}

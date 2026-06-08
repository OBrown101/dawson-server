//
//  SkillHandler.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/20/26.
//

import Foundation

class SkillHandler: @unchecked Sendable {
    static let shared = SkillHandler()
    
    func loadSkills() -> [SkillMetadata] {
        let fileManager = FileManager.default
        
        let skillsRoot = DAWSON.root
            .appendingPathComponent("workspace")
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
        /* Skill metadata format:
        ---
        name: project-review
        description: Rapidly review a new software project...
        ---
        */
        
        let lines = content.components(separatedBy: .newlines)
        
        // Must begin with frontmatter delimiter.
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else {
            return nil
        }
        
        var name: String?
        var description: String?
        var insideFrontmatter = true
        
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // End of frontmatter
            if trimmed == "---" {
                insideFrontmatter = false
                break
            }
            
            guard insideFrontmatter else { break }
            
            if trimmed.hasPrefix("name:") {
                name = extractValue(from: trimmed, key: "name:")
            } else if trimmed.hasPrefix("description:") {
                description = extractValue(from: trimmed, key: "description:")
            }
        }
        
        guard
            let skillName = name,
            let skillDescription = description,
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
    
    // Extracts and unquotes a YAML scalar value.
    private func extractValue(from line: String, key: String) -> String {
        var value = line.dropFirst(key.count).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove matching single or double quotes if present.
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
           (value.hasPrefix("'") && value.hasSuffix("'")) {
            value.removeFirst()
            value.removeLast()
        }
        
        return value
    }
}

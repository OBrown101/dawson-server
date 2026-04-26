//
//  Loader.swift
//  
//
//  Created by Ethan Brown on 3/19/26.
//

import Foundation

class Loader {
    static let shared = Loader()
    
    func buildSystemContent() -> [String] {
        let content = [loadSoul(), loadPrimary(), loadUser(), loadAgents(), loadSkillsSummary()]
        return content
    }
    
    private func loadUser() -> String {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath + "/workspace/config/USER.md")
        if let content = try? String(contentsOf: url) {
            return content
        }
        print("Failed to load USER.md at: \(url.absoluteString)")
        return ""
    }
    
    private func loadAgents() -> String {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath + "/workspace/config/AGENTS.md")
        if let content = try? String(contentsOf: url) {
            return content
        }
        print("Failed to load AGENTS.md at: \(url.absoluteString)")
        return ""
    }
    
    private func loadPrimary() -> String {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath + "/workspace/config/PRIMARY.md")
        if let content = try? String(contentsOf: url) {
            return content
        }
        print("Failed to load PRIMARY.md at: \(url.absoluteString)")
        return ""
    }
    
    private func loadSoul() -> String {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath + "/workspace/config/SOUL.md")
        if let content = try? String(contentsOf: url) {
            return content
        }
        print("Failed to load SOUL.md at: \(url.absoluteString)")
        return ""
    }
    
    private func loadSkillsSummary() -> String {
        var output = "## AVAILABLE SKILLS\n"

        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath + "/workspace/skills/")
        guard let skillFolders = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            print("Failed to load SKILLS at: \(url.absoluteString)")
            return ""
        }

        let fileManager = FileManager.default
        for folder in skillFolders {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue {
                
                let skillFile = folder.appendingPathComponent("skill.md")
                
                guard fileManager.fileExists(atPath: skillFile.path),
                      let content = try? String(contentsOf: skillFile) else { continue }
                
                let parsed = parseSkillFile(content)
                
                output += """
                
                ### \(parsed.name)
                - Purpose: \(parsed.purpose)
                - Example: \(parsed.example)
                
                """
            }
        }

        return output
    }
    
    private func parseSkillFile(_ content: String) -> (name: String, purpose: String, example: String) {
        let lines = content.components(separatedBy: .newlines)
        
        var name = "Unknown Skill"
        var purpose = ""
        var example = ""
        
        var currentSection: String? = nil
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skill name
            if trimmed.hasPrefix("# ") {
                name = trimmed.replacingOccurrences(of: "# ", with: "")
            }
            
            // Section detection
            if trimmed.lowercased().contains("**purpose**") {
                currentSection = "purpose"
                continue
            }
            if trimmed.lowercased().contains("**example usage**") {
                currentSection = "example"
                continue
            }
            
            // Capture content
            if let section = currentSection {
                if trimmed.hasPrefix("**") { continue } // skip new headers
                
                if section == "purpose" {
                    purpose += (trimmed + " ")
                } else if section == "example" {
                    example += (trimmed + " ")
                }
            }
        }
        
        return (name, purpose.trimmingCharacters(in: .whitespaces), example.trimmingCharacters(in: .whitespaces))
    }
}

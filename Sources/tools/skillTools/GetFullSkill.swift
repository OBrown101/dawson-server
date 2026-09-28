//
//  GetFullSkill.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/20/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

class GetFullSkill: Tool {
    static let name = "get_full_skill"
    
    let toolDescription = """
    Loads the full contents of a skill's SKILL.md file using the skill name. Use this when a task matches one of the available skill summaries and the agent needs the detailed instructions.
    """
    
    private let parameterSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "skill_name": [
                "type": "string",
                "description": "The exact name of the skill to load"
            ],
            "file_path": [
                "type": "string",
                "description": "Optional path relative to the skill's directory to load a bundled resource (e.g. references/schemas.md). Omit to load SKILL.md."
            ]
        ],
        "required": ["skill_name"]
    ]
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": GetFullSkill.name,
            "description": toolDescription,
            "parameters": parameterSchema
        ]
    }

    func anthropicSchema() -> [String : Any] {
        return [
            "name": GetFullSkill.name,
            "description": toolDescription,
            "input_schema": [
                "type": "object",
                "properties": parameterSchema
            ]
        ]
    }
    
    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": GetFullSkill.name,
                "description": toolDescription,
                "parameters": parameterSchema
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let skillName = args["skill_name"] as? String else {
            return "Missing required parameter: skill_name"
        }

        let skills = SkillHandler.shared.loadSkills()

        guard let skill = skills.first(where: {
            $0.name.caseInsensitiveCompare(skillName) == .orderedSame
        }) else {
            return """
            Skill not found: \(skillName)

            Available skills:
            \(skills.map(\.name).joined(separator: ", "))
            """
        }
        
        if let relPath = args["file_path"] as? String,
           !relPath.isEmpty {
            let skillDir = URL(fileURLWithPath: skill.directoryPath).standardizedFileURL
            let target = skillDir.appendingPathComponent(relPath).standardizedFileURL
            guard target.path.hasPrefix(skillDir.path + "/") else {
                return "Invalid file_path: must stay within the skill directory."
            }
            guard let content = try? String(contentsOf: target, encoding: .utf8) else {
                return "File not found in skill \(skill.name): \(relPath)"
            }
            return content
        }

        guard let fullSkill = Loader.shared.loadFullSkill(skill) else {
            return "Failed to load full skill file for: \(skill.name)"
        }

        return fullSkill
    }
}

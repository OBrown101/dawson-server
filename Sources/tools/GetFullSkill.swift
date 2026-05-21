//
//  GetFullSkill.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/20/26.
//

import Foundation

class GetFullSkill: Tool {
    let name = "get_full_skill"

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Loads the full contents of a skill's SKILL.md file using the skill name. Use this when a task matches one of the available skill summaries and the agent needs the detailed instructions.",
                "parameters": [
                    "type": "object",
                    "required": ["skill_name"],
                    "properties": [
                        "skill_name": [
                            "type": "string",
                            "description": "The exact name of the skill to load"
                        ]
                    ]
                ]
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

        guard let fullSkill = Loader.shared.loadFullSkill(skill) else {
            return "Failed to load full skill file for: \(skill.name)"
        }

        return fullSkill
    }
}

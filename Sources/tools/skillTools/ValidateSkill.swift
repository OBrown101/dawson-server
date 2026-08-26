//
//  ValidateSkill.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/26/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

class ValidateSkill: Tool {
    static let name = "validate_skill"

    private let toolDescription = """
        Validates a skill folder before installation: checks that SKILL.md \
        exists at the folder root and is the only one in the tree, that the \
        YAML frontmatter parses with non-empty name and description (using \
        the same parser the skill loader uses, so passing here means DAWSON \
        will load it), that the name is lowercase-hyphenated and matches the \
        folder, and that the description fits the 1024-character limit. \
        Returns errors and warnings. Use while creating or editing a skill, \
        before packaging or installing it.
        """

    private let parameterProperties: [String: Any] = [
        "skill_path": [
            "type": "string",
            "description": "Absolute path to the skill folder (the folder containing SKILL.md)"
        ]
    ]

    func openAISchema() -> [String: Any] {
        return [
            "type": "function",
            "name": ValidateSkill.name,
            "description": toolDescription,
            "parameters": [
                "type": "object",
                "required": ["skill_path"],
                "properties": parameterProperties
            ]
        ]
    }

    func anthropicSchema() -> [String: Any] {
        return [
            "name": ValidateSkill.name,
            "description": toolDescription,
            "input_schema": [
                "type": "object",
                "required": ["skill_path"],
                "properties": parameterProperties
            ]
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": ValidateSkill.name,
                "description": toolDescription,
                "parameters": [
                    "type": "object",
                    "required": ["skill_path"],
                    "properties": parameterProperties
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let skillPath = args["skill_path"] as? String,
              (!skillPath.isEmpty) else {
            return "Missing required parameter: skill_path"
        }

        let fileManager = FileManager.default
        let skillDir = URL(fileURLWithPath: (skillPath as NSString).expandingTildeInPath)
            .standardizedFileURL

        guard ((try? skillDir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true) else {
            return "ERROR: Not a directory: \(skillDir.path)"
        }

        var errors: [String] = []
        var warnings: [String] = []

        let skillFile = skillDir.appendingPathComponent("SKILL.md")
        guard let content = try? String(contentsOf: skillFile, encoding: .utf8) else {
            return "ERROR: No readable SKILL.md at \(skillFile.path)"
        }

        // Exactly one SKILL.md — DAWSON loads one per top-level skill folder, nested ones are never read.
        if let enumerator = fileManager.enumerator(at: skillDir, includingPropertiesForKeys: nil) {
            let nested = enumerator.compactMap { $0 as? URL }
                .filter { ($0.lastPathComponent == "SKILL.md") && ($0.standardizedFileURL != skillFile.standardizedFileURL) }
            if (!nested.isEmpty) {
                errors.append(
                    "A skill must contain exactly one SKILL.md, at the folder root. "
                    + "Nested copies are never loaded: "
                    + nested.map { $0.path.replacingOccurrences(of: skillDir.path + "/", with: "") }
                        .joined(separator: ", ")
                )
            }
        }

        // Same parser the loader uses — passing here means DAWSON loads it.
        guard let fields = SkillHandler.shared.frontmatterFields(content) else {
            errors.append("SKILL.md must start with `---` YAML frontmatter closed by `---`.")
            return report(skillDir: skillDir, errors: errors, warnings: warnings)
        }

        let skillName = fields["name"] ?? ""
        let description = fields["description"] ?? ""

        if (skillName.isEmpty) {
            errors.append("Frontmatter is missing a non-empty `name`.")
        } else {
            if (skillName.range(of: "^[a-z0-9]+(-[a-z0-9]+)*$", options: .regularExpression) == nil) {
                errors.append("name `\(skillName)` should be lowercase letters/digits with hyphens (e.g. `pdf-tools`).")
            }
            if (skillName != skillDir.lastPathComponent) {
                warnings.append("name `\(skillName)` differs from folder name `\(skillDir.lastPathComponent)` — keep them identical.")
            }
        }

        if (description.isEmpty) {
            errors.append("Frontmatter is missing a non-empty `description`.")
        } else {
            if (description.count > 1024) {
                errors.append("description is \(description.count) characters; the limit is 1024 (it would be truncated in agent summaries).")
            }
            if (description.count < 60) {
                warnings.append("description is very short — it is the only thing agents see when deciding to load the skill; say what it does AND when to use it.")
            }
        }

        let bodyLines = content.components(separatedBy: .newlines).count
        if (bodyLines > 500) {
            warnings.append("SKILL.md is \(bodyLines) lines (advisory limit ~500); consider moving detail into references/ files.")
        }

        return report(skillDir: skillDir, errors: errors, warnings: warnings)
    }

    private func report(skillDir: URL, errors: [String], warnings: [String]) -> String {
        var lines: [String] = []
        lines.append(contentsOf: warnings.map { "WARNING: \($0)" })
        lines.append(contentsOf: errors.map { "ERROR: \($0)" })

        if (errors.isEmpty) {
            let suffix = warnings.isEmpty ? "" : " (\(warnings.count) warning\(warnings.count == 1 ? "" : "s"))"
            lines.append("\(skillDir.lastPathComponent): valid\(suffix)")
        } else {
            lines.append("\(skillDir.lastPathComponent): INVALID (\(errors.count) error\(errors.count == 1 ? "" : "s"))")
        }
        return lines.joined(separator: "\n")
    }
}

//
//  PackageSkill.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/26/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

class PackageSkill: Tool {
    static let name = "package_skill"

    private let toolDescription = """
        Packages a skill folder into a distributable .skill file (a zip with \
        development artifacts excluded: evals/, *-workspace/, caches, OS \
        junk). Validates the skill first and refuses to package one that \
        fails validation. Writes <skill-name>.skill next to the folder, or \
        into output_path if given. Use when a skill is finished and ready to \
        share or install; installing means unzipping into \
        ~/DAWSON/databank/skills/.
        """

    private let parameterProperties: [String: Any] = [
        "skill_path": [
            "type": "string",
            "description": "Absolute path to the skill folder (the folder containing SKILL.md)"
        ],
        "output_path": [
            "type": "string",
            "description": "Optional directory to write the .skill file into (defaults to the skill folder's parent)"
        ]
    ]

    func openAISchema() -> [String: Any] {
        return [
            "type": "function",
            "name": PackageSkill.name,
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
            "name": PackageSkill.name,
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
                "name": PackageSkill.name,
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
        guard let skillPath = args["skill_path"] as? String, !skillPath.isEmpty else {
            return "Missing required parameter: skill_path"
        }

        let skillDir = URL(fileURLWithPath: (skillPath as NSString).expandingTildeInPath)
            .standardizedFileURL
        let skillName = skillDir.lastPathComponent

        // Never ship a skill the loader would reject.
        let validation = await ValidateSkill().execute(args: ["skill_path": skillDir.path])
        if (validation.contains("INVALID") || validation.hasPrefix("ERROR:")) {
            return "Refusing to package — validation failed:\n\(validation)"
        }

        let outputDir: URL
        if let outputPath = args["output_path"] as? String,
           (!outputPath.isEmpty) {
            outputDir = URL(fileURLWithPath: (outputPath as NSString).expandingTildeInPath)
                .standardizedFileURL
            try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        } else {
            outputDir = skillDir.deletingLastPathComponent()
        }
        let outputFile = outputDir.appendingPathComponent("\(skillName).skill")
        try? FileManager.default.removeItem(at: outputFile)

        // Standard macOS zip; -x patterns are relative to the working
        // directory (the skill folder's parent), so archive paths are
        // "<skill-name>/..." — unzipping into the skills dir installs it.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = skillDir.deletingLastPathComponent()
        process.arguments = [
            "-ry", outputFile.path, skillName,
            "-x",
            "\(skillName)/evals/*",
            "\(skillName)/*-workspace/*",
            "\(skillName)/*__pycache__*",
            "\(skillName)/*.pyc",
            "\(skillName)/*.DS_Store",
            "\(skillName)/*.skill",
            "\(skillName)/feedback.json"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return "Failed to run zip: \(error)"
        }

        guard process.terminationStatus == 0 else {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return "zip exited \(process.terminationStatus):\n\(output.prefix(400))"
        }

        let sizeBytes = (try? FileManager.default.attributesOfItem(atPath: outputFile.path)[.size] as? Int) ?? 0
        let sizeKB = (Double(sizeBytes ?? 0) / 1024.0)
        return """
        Packaged: \(outputFile.path) (\(String(format: "%.1f", sizeKB)) KB)
        Install by unzipping into ~/DAWSON/databank/skills/ — agents pick it up at their next session start.
        """
    }
}

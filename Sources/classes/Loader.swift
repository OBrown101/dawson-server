//
//  Loader.swift
//  DAWSON
//
//  Created by Ethan Brown on 3/19/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

class Loader: @unchecked Sendable {
    static let shared = Loader()
    
    func buildBaseSystemPrompt(agent: Agent.AgentType) async -> String {
        let primarySoul = loadAgentPrimarySoul(agent)
        let dynamicSoul = loadAgentDynamicSoul(agent)
        let memorySchema = await loadMemory()
        let skillSummaries = loadSkillSummaries()
        let pythonTools = loadPythonToolSummaries()
        return [primarySoul, dynamicSoul, skillSummaries, pythonTools, memorySchema].joined(separator: "\n")
    }
    
    func loadMemory() async -> String {
        return """
        ## YOUR MEMORY SETUP ##
        \(await MempalaceMemory.shared.getStatus())
        ## --- ##
        """
    }
    
    func loadAgentPrimarySoul(_ agent: Agent.AgentType) -> String {
        switch (agent) {
        case .dawson:
            return dawsonPrimarySoul
        case .squireBot:
            return squirebotPrimarySoul
        case .page:
            return ""
        }
    }
    
    func loadAgentDynamicSoul(_ agent: Agent.AgentType) -> String {
        guard let soulPath = agent.dynamicSoulPath else { return "" }
        
        let url = DAWSON.root.appendingPathComponent(soulPath)
        if let content = try? String(contentsOf: url) {
            return content
        }
        print("Failed to load agent's dynamic soul at: \(url.absoluteString)")
        return ""
    }
    
    func loadPythonToolSummaries() -> String {
        let summary = ToolCatalog.promptSummary()
        guard (!summary.isEmpty) else { return "" }

        return """
        ## SHARED PYTHON TOOL LIBRARY ##

        Reusable Python tools built in previous conversations, runnable via \
        `\(RunPythonScript.name)` (arguments are passed as keywords). Before writing \
        any new Python code, check whether one of these already solves the task; \
        call `\(ListPythonTools.name)` for full function signatures.

        \(summary)

        ## --- ##
        """
    }
    
    func loadSkillSummaries() -> String {
        let skills = SkillHandler.shared.loadSkills()
        print("Loaded \(skills.count) Skills")
        if (skills.isEmpty) { return "" }
        
        let summaries = skills.map { skill in
            """
            - Name: \(skill.name)
              Description: \(skill.description)
              Directory: \(skill.directoryPath)
            """
        }.joined(separator: "\n")
        
        let fullSkillTool = GetFullSkill.name
        
        return """
        ## BRIEF SUMMARY OF YOUR AVAILABLE SKILLS ##

        The following are brief summaries of specialized skills available to you. A skill is an instruction pack that teaches you how to perform a particular workflow or task.

        Before beginning any non-trivial or multi-step task, first review these summaries and decide whether one clearly matches the user's request.

        If a skill clearly applies:
        1. Call `\(fullSkillTool)` to read its complete instructions.
        2. Follow those instructions while using your normal tools.
        3. Continue the task until it is complete.

        If no skill clearly applies:
        Proceed normally without using a skill.

        Do not call `\(fullSkillTool)` for simple questions, brief explanations, casual conversation, or tasks that do not benefit from a specialized workflow.

        A skill's directory only contains the skill itself. It is **not** the project or data you should operate on unless the user explicitly tells you to work there.
        
        Skills may reference bundled files (references/, agents/, assets/) — load them with \(GetFullSkill.name) by passing file_path."

        Available skills:

        \(summaries)

        ## --- ##
        """
    }
    
    func loadFullSkill(_ skill: SkillMetadata) -> String? {
        try? String(contentsOfFile: skill.skillFilePath, encoding: .utf8)
    }
}

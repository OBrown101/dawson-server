//
//  Loader.swift
//  
//
//  Created by Ethan Brown on 3/19/26.
//

import Foundation

class Loader: @unchecked Sendable {
    static let shared = Loader()
    
    func buildBaseSystemPrompt(agent: Agent.AgentType) -> String {
        let primarySoul = loadAgentPrimarySoul(agent)
        let dynamicSoul = loadAgentDynamicSoul(agent)
        let memorySchema = loadMemory()
        let skillSummaries = loadSkillSummaries()
//        let basicInfo = loadBasicInfo()
        return [primarySoul, dynamicSoul, memorySchema, skillSummaries].joined(separator: "\n")
    }
    
    func loadBasicInfo() -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        formatter.timeZone = TimeZone.current
        let dateString = formatter.string(from: now)
        let timezoneName = TimeZone.current.identifier
        
        return """
        ## BASIC INFO ##
        Date & time: \(dateString)
        Time zone: \(timezoneName)
        ## --- ##
        """
    }
    
    func loadMemory() -> String {
        return """
        ## YOUR MEMORY SETUP ##
        \(MempalaceMemory.shared.getStatus())
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
        
        return """
        ## BRIEF SUMMARY FOR EACH OF YOUR SKILLS ##
        These are lightweight summaries of the skills available to you. Before beginning any multi-step task, check whether one of these skills matches. 
        Skills are instruction packs, not executable tools.

        When a user request matches a skill:
        1. Call get_full_skill to read the skill's SKILL.md.
        2. Follow the instructions from that skill using your normal tools.
        3. Do not try to "run" or "execute" the skill.
        4. The skill directory is only where the instructions live; it is not the target project unless the user explicitly says so.

        Available skills:
        
        \(summaries)
        ## --- ##
        """
    }
    
    func loadFullSkill(_ skill: SkillMetadata) -> String? {
        try? String(contentsOfFile: skill.skillFilePath, encoding: .utf8)
    }
}

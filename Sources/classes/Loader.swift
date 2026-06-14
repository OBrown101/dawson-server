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
        let soul = loadAgentSoul(agent)
        let memorySchema = loadMemory()
        let skillSummaries = loadSkillSummaries()
        let basicInfo = loadBasicInfo()
        return [soul, basicInfo, memorySchema, skillSummaries].joined(separator: "\n")
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
    
    func loadAgentSoul(_ agent: Agent.AgentType) -> String {
        guard let soulPath = agent.soulPath else { return "" }
        
        let url = DAWSON.workspace.appendingPathComponent(soulPath)
        if let content = try? String(contentsOf: url) {
            return content
        }
        print("Failed to load agent's soul at: \(url.absoluteString)")
        return "Failed to load the agent's soul/identity. Tell user about the issue and ask for help."
    }
    
    func loadSkillSummaries() -> String {
        let skills = SkillHandler.shared.loadSkills()
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
        These are lightweight summaries of the skills available to you. If a task matches one of these
        descriptions, load the full SKILL.md from the listed directory to access the complete instructions.
        
        \(summaries)
        ## --- ##
        """
    }
    
    func loadFullSkill(_ skill: SkillMetadata) -> String? {
        try? String(contentsOfFile: skill.skillFilePath, encoding: .utf8)
    }
}

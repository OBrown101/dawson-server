//
//  Loader.swift
//  
//
//  Created by Ethan Brown on 3/19/26.
//

import Foundation

class Loader: @unchecked Sendable {
    static let shared = Loader()
    
    func buildBaseSystemPrompt(agent: AgentType) -> String {
        let soul = loadAgentSoul(agent)
        let memorySchema = ("## YOUR MEMORY SETUP ##\n" + MempalaceMemory.shared.getStatus())
        return (soul + "/n" + memorySchema)
    }
    
    func loadAgentSoul(_ agent: AgentType) -> String {
        let projectRoot = FileManager.default.currentDirectoryPath
        let url = URL(fileURLWithPath: projectRoot + agent.soulPath)
        if let content = try? String(contentsOf: url) {
            return content
        }
        print("Failed to load agent's soul at: \(url.absoluteString)")
        return "Failed to load the agent's soul/identity. Tell user about the issue and ask for help."
    }
}

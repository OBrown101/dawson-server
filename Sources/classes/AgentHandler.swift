//
//  AgentHandler.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/27/26.
//

import Foundation

class AgentHandler: @unchecked Sendable {
    static let shared = AgentHandler()
    
    static let defaultThoughtWindow = 200
    static let defaultContextWindow: Int32 = 32_000
    
    private var activeAgents: [String: Agent] = [:]

    init() {
        let savedAgents = Agent.loadAllAgents()
        activeAgents = Dictionary(uniqueKeysWithValues: savedAgents.map { ($0.uuid, $0) })
        print("Loaded Agents: \(savedAgents)")
    }
    
    func updateAgent(agent: Agent) {
        activeAgents[agent.uuid]?.mode = agent.mode
        activeAgents[agent.uuid]?.model = agent.model
        activeAgents[agent.uuid]?.thoughtWindow = agent.thoughtWindow
        activeAgents[agent.uuid]?.contextWindow = agent.contextWindow
        activeAgents[agent.uuid]?.useThinking = agent.useThinking
        activeAgents[agent.uuid]?.directories = agent.directories
        activeAgents[agent.uuid]?.updatedTimestamp = Int64(Date.now.timeIntervalSince1970)
        activeAgents[agent.uuid]?.saveMetadata()
        
        DAWSON.shared.broadcastAgentUpsert(agent)
    }
    
    func deleteAgent(_ agentUUID: String) {
        let deletedAgent = activeAgents[agentUUID]
        activeAgents[agentUUID]?.deleteAll()
        activeAgents.removeValue(forKey: agentUUID)
        print("Agent (\(agentUUID) deleted.")
        if let agent = deletedAgent {
            DAWSON.shared.broadcastAgentDelete(agent)
        }
    }
    
    func deleteAgentsForUser(_ userUUID: String) {
        let agentUUIDs = activeAgents.values.filter({ $0.userUUID == userUUID }).map({ $0.uuid })
        agentUUIDs.forEach { uuid in
            deleteAgent(uuid)
        }
    }
    
    func getAgents() -> [Agent] {
        return activeAgents.values.map { $0 }
    }
    
    func getAgent(_ agentUUID: String) -> Agent? {
        return activeAgents[agentUUID]
    }
    
    func spawnAgent(
        uuid: String,
        userUUID: String,
        type: Agent.AgentType,
        mode: ModeType = .egg,
        model: LLMModel,
        thoughtWindow: Int = defaultThoughtWindow,
        contextWindow: Int32 = defaultContextWindow,
        useThinking: Bool = true
    ) {
        let newAgent = Agent(
            uuid: uuid,
            userUUID: userUUID,
            type: type,
            mode: mode,
            model: model,
            thoughtWindow: thoughtWindow,
            contextWindow: contextWindow,
            useThinking: useThinking
        )
        if (!activeAgents.keys.contains(uuid)) {
            activeAgents[uuid] = newAgent
            newAgent.saveMetadata()
            print("New agent (\(uuid)) spawned.")
        } else {
            print("Agent (\(uuid)) already exists.")
        }
    }
    
    func runAgent(runUUID: String, userUUID: String, agentUUID: String, prompt: String, onEvent: ((_ event: AgentEvent, _ runUUID: String) -> Void)? = nil) async -> [Message] {
        guard let agent = activeAgents[agentUUID] else { return [] }
        
        let systemPrompt = (agent.getHistory().isEmpty) ? Loader.shared.buildBaseSystemPrompt(agent: agent.type) : ""
        
        do {
            return try await agent.runAgent(runUUID: runUUID, userPrompt: prompt, systemPrompt: systemPrompt, onEvent: onEvent)
        } catch {
            print(error.localizedDescription)
            return []
        }
    }
    
    func resumeAgent(response: UserInputResponse, onEvent: ((_ event: AgentEvent, _ runUUID: String) -> Void)? = nil) async -> [Message] {
        guard let agent = activeAgents[response.agentUUID] else {
            print("Missing suspend data or agent")
            return []
        }

        do {
            return try await agent.resumeAgent(userResponse: response, onEvent: onEvent)
        } catch {
            print(error.localizedDescription)
            return []
        }
    }
}

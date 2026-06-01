//
//  AgentHandler.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/27/26.
//

import Foundation

class AgentHandler: @unchecked Sendable {
    static let shared = AgentHandler()
    
    static let defaultModel = "gpt-oss-20b-32k-16k"
    let defaultMaxMessage = 200
    
    private var activeAgents: [String: Agent] = [:]

    init() {
        let savedAgents = Agent.loadAllAgents()
        activeAgents = Dictionary(uniqueKeysWithValues: savedAgents.map { ($0.uuid, $0) })
        print("Loaded Chats: \(savedAgents)")
    }
    
    func getAgent(_ agentUUID: String) -> Agent? {
        return activeAgents[agentUUID]
    }
    
    func spawnAgent(uuid: String, userUUID: String, type: Agent.AgentType, mode: ModeType = .egg, model: String = defaultModel) {
        let newAgent = Agent(
            uuid: uuid,
            userUUID: userUUID,
            type: type,
            mode: mode,
            model: model,
            maxMessages: defaultMaxMessage
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

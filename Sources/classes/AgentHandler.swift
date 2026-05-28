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
    let primaryAgentUUID = "PRIMARY"
    
    private var activeAgents: [String: Agent] = [:]

    
    func getAgent(_ agentUUID: String) -> Agent? {
        return activeAgents[agentUUID]
    }
    
    func spawnPrimaryAgent() {
//        spawnAgent(uuid: primaryAgentUUID, type: .dawson, model: AgentHandler.defaultModel)     // Sets up primary Dawson agent
    }
    
    func spawnAgent(uuid: String, userUUID: String, type: Agent.AgentType, mode: ModeType = .egg, model: String = defaultModel) {
        let newAgent = Agent(
            uuid: uuid,
            userUUID: userUUID,
            type: type,
            mode: mode,
            model: model,
            maxMessages: defaultMaxMessage,
            tools: [
                WriteFile(), SearchFile(), PatchFile(), ReplaceInFile(), ReadFile(), ListFiles(), Speak(), SelfConfig(), RichFormatter()
            ]
        )
        if (!activeAgents.keys.contains(uuid)) {
            activeAgents[uuid] = newAgent
            print("New agent spawned: \(uuid)")
        } else {
            print("Agent already exists: \(uuid)")
        }
    }
    
    func runAgent(userUUID: String, agentUUID: String, prompt: String, onEvent: ((_ event: AgentEvent, _ runUUID: String) -> Void)? = nil) async -> [Message] {
        guard let agent = activeAgents[agentUUID] else { return [] }
        
        let systemPrompt = (agent.getHistory().isEmpty) ? Loader.shared.buildBaseSystemPrompt(agent: agent.type) : ""
        
        do {
            let messages = try await agent.runAgent(userPrompt: prompt, systemPrompt: systemPrompt, onEvent: onEvent)
            return messages
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
            let messages = try await agent.resumeAgent(userResponse: response, onEvent: onEvent)
            return messages
        } catch {
            print(error.localizedDescription)
            return []
        }
    }
}

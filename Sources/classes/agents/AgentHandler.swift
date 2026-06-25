//
//  AgentHandler.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/27/26.
//

import Foundation

class AgentHandler: @unchecked Sendable {
    static let shared = AgentHandler()
    
    static let defaultThoughtWindow = 0
    static let defaultContextWindow: Int32 = 128_000
    
    private var activeAgents: [String: Agent] = [:]

    init() {
        let savedAgents = Agent.loadAllAgents()
        activeAgents = Dictionary(uniqueKeysWithValues: savedAgents.map { ($0.uuid, $0) })
        print("Loaded Agents: \(savedAgents)")
    }
    
    func updateAgent(agent: Agent) {
        activeAgents[agent.uuid]?.mode = agent.mode
        activeAgents[agent.uuid]?.setModel(agent.model)
        activeAgents[agent.uuid]?.thoughtWindow = agent.thoughtWindow
        activeAgents[agent.uuid]?.contextWindow = agent.contextWindow
        activeAgents[agent.uuid]?.useThinking = agent.useThinking
        activeAgents[agent.uuid]?.directories = agent.directories
        activeAgents[agent.uuid]?.updatedTimestamp = Date.now.epochMillis
        activeAgents[agent.uuid]?.saveMetadata()
        
        if let updatedAgent = activeAgents[agent.uuid] {
            DAWSON.shared.broadcastAgentUpsert(updatedAgent)
        }
    }
    
    func deleteAgent(_ agentUUID: String) {
        Task {
            await AgentRunRegistry.shared.cancelAgentRun(agentUUID: agentUUID)
            
            let deletedAgent = activeAgents[agentUUID]
            activeAgents[agentUUID]?.deleteAll()
            activeAgents.removeValue(forKey: agentUUID)
            print("Agent (\(agentUUID) deleted.")
            if let agent = deletedAgent {
                DAWSON.shared.broadcastAgentDelete(agent)
            }
        }
    }
    
    func deleteAgentsForUser(_ userUUID: String) {
        let agentUUIDs = activeAgents.values.filter({ $0.userUUID == userUUID }).map({ $0.uuid })
        agentUUIDs.forEach { uuid in
            deleteAgent(uuid)
        }
    }
    
    func getAgents(userUUID: String) -> [Agent] {
        return activeAgents.values.filter({ $0.userUUID == userUUID }).map { $0 }
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
            DAWSON.shared.broadcastAgentUpsert(newAgent)
        } else {
            print("Agent (\(uuid)) already exists.")
        }
    }
    
    func runAgent(runUUID: String, userUUID: String, agentUUID: String, prompt: String, onEvent: @escaping (@Sendable (_ event: AgentEvent, _ runUUID: String) async -> Void)) async -> [Message] {
        guard let agent = activeAgents[agentUUID] else { return [] }
        
        let systemPrompt = (agent.getHistory().isEmpty) ? Loader.shared.buildBaseSystemPrompt(agent: agent.type) : ""
        
        let task = Task<[Message], Error> {
            try Task.checkCancellation()

            return try await agent.runAgent(runUUID: runUUID, userPrompt: prompt, systemPrompt: systemPrompt, onEvent: onEvent)
        }
        await AgentRunRegistry.shared.register(runUUID: runUUID, agentUUID: agentUUID, task: task)
        
        defer {
            Task {
                await AgentRunRegistry.shared.remove(runUUID: runUUID)
            }
        }
        
        do {
            return try await task.value
        } catch is CancellationError {
            return []
        } catch {
            print("Agent run failed: \(error)")
            return []
        }
    }
    
    func resumeAgent(response: UserInputResponse, onEvent: @escaping (@Sendable (_ event: AgentEvent, _ runUUID: String) async -> Void)) async -> [Message] {
        guard let agent = activeAgents[response.agentUUID],
              let runUUID = agent.suspendData?.runUUID else {
            print("Missing suspend data or agent")
            return []
        }
        
        let task = Task<[Message], Error> {
            try Task.checkCancellation()
            return try await agent.resumeAgent(userResponse: response, onEvent: onEvent)
        }

        await AgentRunRegistry.shared.register(
            runUUID: runUUID,
            agentUUID: response.agentUUID,
            task: task
        )

        defer {
            Task {
                await AgentRunRegistry.shared.remove(runUUID: runUUID)
            }
        }

        do {
            return try await task.value
        } catch is CancellationError {
            return []
        } catch {
            print("Resume agent failed: \(error)")
            return []
        }
    }
    
    func cancelRun(_ runUUID: String) async {
        await AgentRunRegistry.shared.cancel(runUUID: runUUID)
    }

    func cancelAgentRun(_ agentUUID: String) async {
        await AgentRunRegistry.shared.cancelAgentRun(agentUUID: agentUUID)
    }
}

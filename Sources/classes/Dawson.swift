//
//  DAWSON.swift
//  DAWSON
//
//  Created by Ethan Brown.
//

import Foundation

class DAWSON {
    let server: WebSocketServer

    static let root = FileManager.default.currentDirectoryPath
    static let workspace = (root + "/workspace" as NSString).expandingTildeInPath

    let firstUserPrompt = "Hello, wake up and be ready to take commands."
    let defaultMaxMessage = 100
    let defaultModel = "gpt-oss-20b-32k-16k"  // "qwen3.5-tools"
    let primaryAgentUUID = "PRIMARY"
    static let defaultChatSessionUUID = "PRIMARY_CHAT"

    var activeAgents: [String: Agent] = [:]
    var chatSessions: [String: ChatSessionInfo] = [:]

    init() {
        server = WebSocketServer()
        server.dawson = self
        let _ = spawnAgent(uuid: primaryAgentUUID, type: .dawson, model: defaultModel)     // Sets up primary Dawson agent
    }

    func spawnAgent(uuid: String, type: AgentType, model: String? = nil) -> Agent {
        let newAgent = Agent(
            uuid: uuid,
            type: type,
            model: model ?? defaultModel,
            maxMessages: defaultMaxMessage,
            tools: [
                EnvAwareness(), GetSessionInfo(), GetFullSkill(), WriteFile(), SearchFile(), PatchFile(), ReplaceInFile(), ReadFile(), ListFiles(), WriteFile(), Speak(), SelfConfig(), RichFormatter()
            ]
        )
        activeAgents[uuid] = newAgent
        return newAgent
    }

    func run(userUUID: String, agentUUID: String, prompt: String, chatSessionUUID: String = defaultChatSessionUUID, onEvent: ((_ event: AgentEvent, _ sessionUUID: String) -> Void)? = nil) async -> [Message] {
        guard let agent = activeAgents[agentUUID] else { return [] }
        
        let systemPrompt = (agent.getHistory().isEmpty) ? Loader.shared.buildBaseSystemPrompt(agent: agent.type) : ""
        let chatSession = chatSessions[chatSessionUUID] ?? startNewChatSession(userUUID: userUUID)
        let (_, messages) = await agent.runAgent(userPrompt: prompt, systemPrompt: systemPrompt, chatSession: chatSession, onEvent: onEvent)
        return messages
    }
}

extension DAWSON {
    func startNewChatSession(userUUID: String, mode: Mode = .fledgling) -> ChatSessionInfo {
        let chatUUID = UUID().uuidString
        let newChatSession = ChatSessionInfo(userUUID: userUUID, mode: mode)
        chatSessions[chatUUID] = newChatSession
        return newChatSession
    }
}

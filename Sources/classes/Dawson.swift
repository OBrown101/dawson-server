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
    let defaultModel = "gpt-oss-20b-32k-16k"
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
                WriteFile(), SearchFile(), PatchFile(), ReplaceInFile(), ReadFile(), ListFiles(), Speak(), SelfConfig(), RichFormatter()
            ],
            saveChatSession: { suspendData in
                self.saveChatSuspendData(suspendData: suspendData)
            }
        )
        activeAgents[uuid] = newAgent
        return newAgent
    }

    func run(userUUID: String, agentUUID: String, prompt: String, chatSessionUUID: String = defaultChatSessionUUID, onEvent: ((_ event: AgentEvent, _ runUUID: String) -> Void)? = nil) async -> [Message] {
        guard let agent = activeAgents[agentUUID] else { return [] }
        
        let systemPrompt = (agent.getHistory().isEmpty) ? Loader.shared.buildBaseSystemPrompt(agent: agent.type) : ""
        
        let chatSession: ChatSessionInfo
        if let existing = chatSessions[chatSessionUUID] {
            chatSession = existing
        } else {
            let newSession = ChatSessionInfo(uuid: UUID().uuidString, userUUID: userUUID, mode: .fledgling)  // Currently hard-coded mode, will need change later
            chatSessions[chatSessionUUID] = newSession
            chatSession = newSession
        }
        
        let (_, messages) = await agent.runAgent(userPrompt: prompt, systemPrompt: systemPrompt, chatSession: chatSession, onEvent: onEvent)
        return messages
    }
    
    func resume(response: UserInputResponse, onEvent: ((_ event: AgentEvent, _ runUUID: String) -> Void)? = nil) async -> [Message] {
        guard let session = chatSessions.first(where: { $0.value.suspendData?.userInputRequest?.uuid == response.requestUUID })?.value else {
            print("Unable to find session for requestUUID: \(response.requestUUID)")
            return []
        }
        
        guard let suspendData = session.suspendData,
              let agent = activeAgents[suspendData.agentUUID] else {
            print("Missing suspend data or agent")
            return []
        }

        let (_, messages) = await agent.resumeAgent(chatSession: session, userResponse: response, onEvent: onEvent)
        return messages
    }
}

extension DAWSON {
    func saveChatSuspendData(suspendData: ChatSuspendData) {
        chatSessions[suspendData.chatSessionUUID]?.suspendData = suspendData
    }
}

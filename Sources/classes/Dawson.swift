//
//  DAWSON.swift
//  DAWSON
//
//  Created by Ethan Brown.
//

import Foundation

class DAWSON: @unchecked Sendable {
    static let shared = DAWSON()
    
    let server: WebSocketServer

    static let root = FileManager.default.currentDirectoryPath
    static let workspace = (root + "/workspace" as NSString).expandingTildeInPath

    static let defaultChatSessionUUID = "PRIMARY_CHAT"

    private var activeChats: [String: Chat] = [:]

    init() {
        server = WebSocketServer()
        server.dawson = self
        
        AgentHandler.shared.spawnPrimaryAgent()
    }
    
    func getChat(_ uuid: String) -> Chat? {
        return activeChats[uuid]
    }
    
    func getChatForAgent(_ agentUUID: String) -> Chat? {
        return activeChats.first(where: { $0.value.agentUUID == agentUUID })?.value
    }
    
    func getAllMessages(_ chatUUID: String) -> [MessageData] {
        return activeChats[chatUUID]?.messages ?? []
    }
    
    func getChatResponse(chatUUID: String, prompt: String, onEvent: ((_ event: AgentEvent, _ runUUID: String) -> Void)? = nil) async {
        await activeChats[chatUUID]?.getResponse(prompt: prompt, onEvent: onEvent)
    }
    
    func getChatResumedResponse(response: UserInputResponse, onEvent: ((_ event: AgentEvent, _ runUUID: String) -> Void)? = nil) async {
        guard let chatUUID = activeChats.values.first(where: { ($0.userUUID == response.userUUID) && ($0.agentUUID == response.agentUUID) })?.uuid else { return }
        await activeChats[chatUUID]?.getResumedResponse(response: response, onEvent: onEvent)
    }
    
    func upsertChat(_ chat: Chat) {
        if (!activeChats.keys.contains(chat.uuid)) {
            AgentHandler.shared.spawnAgent(uuid: chat.agentUUID, userUUID: chat.userUUID, type: .dawson)
            activeChats[chat.uuid] = chat
            print("New chat created: \(chat.uuid)")
        } else {
            // Currently no other chat info, this is where settings, etc. would be updated
        }
        // TODO: Notification to sync devices
    }
    
    func deleteChat(_ chatUUID: String) {
        activeChats.removeValue(forKey: chatUUID)
        // TODO: Notification to sync devices
    }
}

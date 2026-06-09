//
//  DAWSON.swift
//  DAWSON
//
//  Created by Ethan Brown.
//

import Foundation
import AnyCodable

class DAWSON: @unchecked Sendable {
    static let shared = DAWSON()
    
    let server: WebSocketServer

    static let root = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("DAWSON")

    static let workspace = DAWSON.root
        .appendingPathComponent("workspace")

    static let primaryChatUUID = "PRIMARY_CHAT"
    static let primaryAgentUUID = "PRIMARY_AGENT"

    private var activeChats: [String: Chat] = [:]

    init() {
        server = WebSocketServer()
        server.dawson = self
        
        let savedChats = Chat.loadAllChats()
        activeChats = Dictionary(uniqueKeysWithValues: savedChats.map { ($0.uuid, $0) })
        print("Loaded Chats: \(savedChats)")
    }
    
    func getAllChats() -> [Chat] {
        return Array(activeChats.values)
    }
    
    func getChat(_ uuid: String) -> Chat? {
        return activeChats[uuid]
    }
    
    func getChatForAgent(_ agentUUID: String) -> Chat? {
        return activeChats.first(where: { $0.value.agentUUID == agentUUID })?.value
    }
    
    func getAllMessages(userUUID: String) -> [MessageData] {
        return Array(activeChats.values.filter({ $0.userUUID == userUUID })).flatMap({ $0.messages })
    }
    
    func getMessagesForChat(_ chatUUID: String) -> [MessageData] {
        return activeChats[chatUUID]?.messages ?? []
    }
    
    func getChatResponse(chatUUID: String, runUUID: String, prompt: String, onEvent: ((_ event: AgentEvent, _ runUUID: String) -> Void)? = nil) async {
        await activeChats[chatUUID]?.getResponse(runUUID: runUUID, prompt: prompt, onEvent: onEvent)
    }
    
    func getChatResumedResponse(response: UserInputResponse, onEvent: ((_ event: AgentEvent, _ runUUID: String) -> Void)? = nil) async {
        guard let chatUUID = activeChats.values.first(where: { ($0.userUUID == response.userUUID) && ($0.agentUUID == response.agentUUID) })?.uuid else { return }
        await activeChats[chatUUID]?.getResumedResponse(response: response, onEvent: onEvent)
    }
    
    func upsertChat(_ chat: Chat) async {
        if (!activeChats.keys.contains(chat.uuid)) {
            if (chat.uuid == DAWSON.primaryChatUUID) {
                await createPrimaryChat(userUUID: chat.userUUID)
            } else {
                await createSquireChat(chatUUID: chat.uuid, userUUID: chat.userUUID, agentUUID: chat.agentUUID)
            }
        } else {
            updateChat(chat)
        }
        print("Chat (\(chat.uuid) upserted.")
    }
}

extension DAWSON {
    func createPrimaryChat(userUUID: String) async {
        guard !activeChats.values.contains(where: { $0.userUUID == userUUID && $0.agentUUID == DAWSON.primaryAgentUUID }) else {
            print("Primary chat already exists for user (\(userUUID))")
            return
        }
        
        guard let model = await Provider.getProviders().flatMap({ $0.models }).first else {
            print("No models available to create Primary Chat for user (\(userUUID))")
            return
        }
        AgentHandler.shared.spawnAgent(uuid: DAWSON.primaryAgentUUID, userUUID: userUUID, type: .dawson, model: model)
        let newChat = Chat(uuid: DAWSON.primaryChatUUID, userUUID: userUUID, agentUUID: DAWSON.primaryAgentUUID)
        activeChats[DAWSON.primaryChatUUID] = newChat
        newChat.saveMetadata()
        print("Primary chat created for user (\(userUUID))")
        
        broadcastChat(newChat)
    }
    
    func createSquireChat(chatUUID: String, userUUID: String, agentUUID: String? = nil) async {
        let agentUUID = agentUUID ?? UUID().uuidString
        guard !activeChats.values.contains(where: { $0.userUUID == userUUID && $0.agentUUID == agentUUID }) else {
            print("Chat already exists for user (\(userUUID)) agent (\(agentUUID))")
            return
        }
        
        guard let model = await Provider.getProviders().flatMap({ $0.models }).first else {
            print("No models available to create Primary Chat for user (\(userUUID))")
            return
        }
        
        AgentHandler.shared.spawnAgent(uuid: agentUUID, userUUID: userUUID, type: .squireBot, model: model)
        let newChat = Chat(uuid: chatUUID, userUUID: userUUID, agentUUID: agentUUID)
        activeChats[chatUUID] = newChat
        newChat.saveMetadata()
        print("New chat (\(chatUUID)) created for user (\(userUUID)) with agent (\(agentUUID)")
        
        broadcastChat(newChat)
    }
    
    func updateChat(_ chat: Chat) {
        // Currently no other chat info, this is where settings, etc. would be updated
        activeChats[chat.uuid]?.title = chat.title
        activeChats[chat.uuid]?.subtitle = chat.subtitle
        activeChats[chat.uuid]?.updatedTimestamp = Int64(Date.now.timeIntervalSince1970)
        print("Chat (\(chat.uuid) updated.")
        // broadcastChat(chat)
    }
    
    func deleteChat(_ chatUUID: String) {
        activeChats[chatUUID]?.deleteAll()
        if let agentUUID = activeChats[chatUUID]?.agentUUID {
            AgentHandler.shared.deleteAgent(agentUUID)
        }
        activeChats.removeValue(forKey: chatUUID)
        print("Chat (\(chatUUID) deleted.")
        // TODO: Notification to sync user devices
    }
    
    func deleteChatsForUser(_ userUUID: String) {
        let chatUUIDs = activeChats.values.filter({ $0.userUUID == userUUID }).map({ $0.uuid })
        chatUUIDs.forEach { uuid in
            deleteChat(uuid)
        }
    }
}

extension DAWSON {
    func broadcastChat(_ chat: Chat) {
        guard let encoded = try? JSONEncoder().encode(chat),
              let payload = try? JSONDecoder().decode(AnyCodable.self, from: encoded) else { return }
        let chatData = ChatData(
            chatUUID: chat.uuid,
            userUUID: chat.userUUID,
            agentUUID: chat.agentUUID,
            dataType: .upsert,
            payload: payload
        )
        let response = WSPacket(type: .chatData, payload: AnyCodable(chatData))
        server.broadcast(response)
    }
}

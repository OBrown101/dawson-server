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

    #if DEBUG
    static let root = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("DAWSON")
    #else
    static let root = URL(fileURLWithPath: CommandLine.arguments[0])
        .resolvingSymlinksInPath()
        .deletingLastPathComponent()
    #endif

    static let databank = DAWSON.root
        .appendingPathComponent("databank")

    static let primaryChatUUID = "PRIMARY_CHAT"
    static let primaryAgentUUID = "PRIMARY_AGENT"

    private var activeChats: [String: Chat] = [:]

    init() {
        print("DAWSON root: \(DAWSON.root.path)")
        print("DAWSON databank: \(DAWSON.databank.path))")
        
        server = WebSocketServer()
        server.dawson = self
        
        let savedChats = Chat.loadAllChats()
        activeChats = Dictionary(uniqueKeysWithValues: savedChats.map { ($0.uuid, $0) })
        print("Loaded Chats: \(savedChats)")
    }
    
    func getAllChats(userUUID: String) -> [Chat] {
        return Array(activeChats.values.filter({ $0.userUUID == userUUID }))
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
        
        broadcastChatUpsert(newChat)
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
        
        broadcastChatUpsert(newChat)
    }
    
    func updateChat(_ chat: Chat) {
        activeChats[chat.uuid]?.title = chat.title
        activeChats[chat.uuid]?.updatedTimestamp = Date.now.epochMillis
        activeChats[chat.uuid]?.saveMetadata()
        print("Chat (\(chat.uuid) updated.")
        if let updatedChat = activeChats[chat.uuid] {
            broadcastChatUpsert(updatedChat)
        }
    }
    
    func deleteChat(_ chatUUID: String) {
        let deletedChat = activeChats[chatUUID]
        activeChats[chatUUID]?.deleteAll()
        if let agentUUID = activeChats[chatUUID]?.agentUUID {
            AgentHandler.shared.deleteAgent(agentUUID)
        }
        activeChats.removeValue(forKey: chatUUID)
        print("Chat (\(chatUUID) deleted.")
        if let chat = deletedChat {
            broadcastChatDelete(chat)
        }
    }
    
    func deleteChatsForUser(_ userUUID: String) {
        let chatUUIDs = activeChats.values.filter({ $0.userUUID == userUUID }).map({ $0.uuid })
        chatUUIDs.forEach { uuid in
            deleteChat(uuid)
        }
    }
}

extension DAWSON {
    func broadcastChatUpsert(_ chat: Chat) {
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
    
    func broadcastChatDelete(_ chat: Chat) {
        guard let encoded = try? JSONEncoder().encode(chat.uuid),
              let payload = try? JSONDecoder().decode(AnyCodable.self, from: encoded) else { return }
        let chatData = ChatData(
            chatUUID: chat.uuid,
            userUUID: chat.userUUID,
            agentUUID: chat.agentUUID,
            dataType: .delete,
            payload: payload
        )
        let response = WSPacket(type: .chatData, payload: AnyCodable(chatData))
        server.broadcast(response)
    }
    
    func broadcastAgentUpsert(_ agent: Agent) {
        guard let encoded = try? JSONEncoder().encode(agent),
              let payload = try? JSONDecoder().decode(AnyCodable.self, from: encoded) else { return }
        let configData = ConfigData(
            userUUID: agent.userUUID,
            agentUUID: agent.uuid,
            providerType: nil,
            dataType: .updateAgent,
            payload: payload
        )
        let response = WSPacket(type: .configData, payload: AnyCodable(configData))
        server.broadcast(response)
    }
    
    func broadcastAgentDelete(_ agent: Agent) {
        guard let encoded = try? JSONEncoder().encode(agent.uuid),
              let payload = try? JSONDecoder().decode(AnyCodable.self, from: encoded) else { return }
        let configData = ConfigData(
            userUUID: agent.userUUID,
            agentUUID: agent.uuid,
            providerType: nil,
            dataType: .deleteAgent,
            payload: payload
        )
        let response = WSPacket(type: .configData, payload: AnyCodable(configData))
        server.broadcast(response)
    }
}

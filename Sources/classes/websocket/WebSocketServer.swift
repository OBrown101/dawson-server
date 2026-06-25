//
//  WebSocketServer.swift
//  
//
//  Created by Ethan Brown on 4/9/26.
//

import Foundation
import Vapor
import AnyCodable

final class WebSocketServer: @unchecked Sendable {

    weak var dawson: DAWSON?
    
    private var chunkBuffers: [String: [String?]] = [:]
    private let maxPacketChars = 32_000
    
    private var connections: [UUID: WebSocket] = [:]

    func handle(_ ws: WebSocket) {
        ws.eventLoop.execute { [weak self] in
            guard let self else { return }
            
            let id = UUID()
            connections[id] = ws
            
            ws.onText { [weak self] ws, text in
                Task {
                    await self?.onReceive(json: text, ws: ws)
                }
            }
            
            ws.onClose.whenComplete { [weak self] _ in
                self?.connections.removeValue(forKey: id)
            }
        }
    }

    private func onReceive(json: String, ws: WebSocket) async {
//        print("raw json received: \(json)")
        guard let data = json.data(using: .utf8),
              let packet: WSPacket = try? JSONDecoder().decode(WSPacket.self, from: data) else { return }
        
        if (packet.isChunk) {
            await handleChunk(packet, ws: ws)
            return
        }
//        print("packet: \(packet.payload)")
        
        switch (packet.type) {
        case .ping:
            await send(WSPacket(type: .pong, payload: "pong"), ws: ws)
            
        case .syncState:
            guard let payload: SyncState = guardPayload(packet.payload, dataType: packet.type.rawValue, ws: ws) else { return }
            await handleSyncState(payload, ws: ws)
            
        case .userData:
            guard let payload: UserData = guardPayload(packet.payload, dataType: packet.type.rawValue, ws: ws) else { return }
            await handleUserData(payload, ws: ws)

        case .chatData:
            guard let payload: ChatData = guardPayload(packet.payload, dataType: packet.type.rawValue, ws: ws) else { return }
            await handleChatData(payload, ws: ws)
            
        case .userInputRequestResponse:
            guard let payload: UserInputResponse = guardPayload(packet.payload, dataType: packet.type.rawValue, ws: ws) else { return }
            await handleUserInputResponse(payload, ws: ws)
            
        case .configData:
            guard let payload: ConfigData = guardPayload(packet.payload, dataType: packet.type.rawValue, ws: ws) else { return }
            await handleConfigData(payload, ws: ws)
            
        default:
            await send(WSPacket(type: .error, payload: "Unknown packet type"), ws: ws)
        }
    }
    
    private func handleChunk(_ packet: WSPacket, ws: WebSocket) async {
        guard let transferUUID = packet.transferUUID,
              let index = packet.index,
              let total = packet.total,
              let chunkText: String = guardPayload(packet.payload, dataType: packet.type.rawValue, ws: ws) else { return }

        if (chunkBuffers[transferUUID] == nil) {
            chunkBuffers[transferUUID] = Array(repeating: nil, count: total)
        }

        guard (index >= 0),
              (index < (chunkBuffers[transferUUID]?.count ?? 0)) else { return }

        chunkBuffers[transferUUID]?[index] = chunkText

        guard let buffer = chunkBuffers[transferUUID],
              buffer.allSatisfy({ $0 != nil }) else { return }

        chunkBuffers.removeValue(forKey: transferUUID)

        let reassembled = buffer.compactMap { $0 }.joined()
        await onReceive(json: reassembled, ws: ws)
    }

    private func send(_ message: WSPacket, ws: WebSocket) async {
        guard let data = try? JSONEncoder().encode(message),
              let text = String(data: data, encoding: .utf8) else { return }
        await sendEncoded(text, originalType: message.type, ws: ws)
    }
    
    private func sendTask(_ message: WSPacket, ws: WebSocket) {
        Task { [weak self, message, ws] in
            guard let self else { return }
            await self.send(message, ws: ws)
        }
    }
    
    private func sendEncoded(_ text: String, originalType: WSPacket.PacketType, ws: WebSocket) async {
        if (text.count <= maxPacketChars) {
            try? await ws.send(text)
            return
        }

        let transferUUID = UUID().uuidString
        let chunks = text.chunked(into: maxPacketChars)

        for index in chunks.indices {
            let chunkPacket = WSPacket(
                type: originalType,
                payload: AnyCodable(chunks[index]),
                transferUUID: transferUUID,
                index: index,
                total: chunks.count
            )

            guard let data = try? JSONEncoder().encode(chunkPacket),
                  let chunkText = String(data: data, encoding: .utf8) else { continue }

            try? await ws.send(chunkText)
        }
    }
    
    func broadcast(_ message: WSPacket) {
        for ws in connections.values {
            sendTask(message, ws: ws)
        }
    }
}

extension WebSocketServer {
    
    private func handleUserData(_ userData: UserData, ws: WebSocket) async {
        guard let dawson = dawson else { return }
        
        switch (userData.dataType) {
        case .textPrompt:
            guard let textPrompt: String = guardPayload(userData.payload, dataType: userData.dataType.rawValue, ws: ws) else { return }
            
            var deliveredUserData = userData
            deliveredUserData.payload = AnyCodable("")
            let response = WSPacket(type: .userData, payload: AnyCodable(deliveredUserData))
            sendTask(response, ws: ws)
            
            let streamState = AgentEventStreamState()
            await dawson.getChatResponse(chatUUID: userData.chatUUID, runUUID: userData.dataUUID, prompt: textPrompt,
                onEvent: { event, runUUID in
                    var dataType: AgentData.DataType
                    var payload: AnyCodable
                    let index = await streamState.getIndex(for: event.key)
                    await streamState.setCurrentRunUUID(runUUID)
                    
                    switch event {
                    case .agentState(let state):
                        dataType = .agentState
                        payload = AnyCodable(state)
                        
                    case .thinking(let text):
                        dataType = .textThinking
                        payload = AnyCodable(text)
                        
                    case .content(let text):
                        dataType = .textResponse
                        payload = AnyCodable(text)
                        
                    case .toolCall(let name):
                        dataType = .toolCall
                        payload = AnyCodable(name)
                        
                    case .toolResult(let result):
                        dataType = .toolResult
                        payload = AnyCodable(result)
                        
                    case .userInputRequest(let prompt):
                        dataType = .userInputRequest
                        payload = AnyCodable(prompt)
                        await streamState.setCurrentRunUUID(nil)    // Input-request stops run-loop (to be resumed), can't permit sending "final message" index
                    }
                
                    let agentData = AgentData(
                        dataUUID: runUUID,
                        dataIndex: index,
                        agentUUID: userData.agentUUID,
                        userUUID: userData.userUUID,
                        dataType: dataType,
                        payload: payload
                    )
                    let response = WSPacket(type: .agentData, payload: AnyCodable(agentData))
                    await streamState.incrIndex(for: event.key)
                    self.sendTask(response, ws: ws)
                }
            )
            
            if let finalState = await streamState.finalState() {
                sendAgentDataCompleted(
                    runUUID: finalState.runUUID,
                    lastDataIndex: finalState.lastDataIndex,
                    userUUID: userData.userUUID,
                    agentUUID: userData.agentUUID,
                    ws: ws
                )
            }
        case .dataPrompt:
            break
        }
    }
    
    private func handleUserInputResponse(_ response: UserInputResponse, ws: WebSocket) async {
        guard let dawson = dawson else { return }
        var dataIndex: [String: Int32] = [:]

        let streamState = AgentEventStreamState()
        await dawson.getChatResumedResponse(response: response,
            onEvent: { event, runUUID in
                var dataType: AgentData.DataType
                var payload: AnyCodable
                let index = await streamState.getIndex(for: event.key)
                await streamState.setCurrentRunUUID(runUUID)

                switch event {
                case .agentState(let state):
                    dataType = .agentState
                    payload = AnyCodable(state)
                    
                case .thinking(let text):
                    dataType = .textThinking
                    payload = AnyCodable(text)

                case .content(let text):
                    dataType = .textResponse
                    payload = AnyCodable(text)

                case .toolCall(let name):
                    dataType = .toolCall
                    payload = AnyCodable(name)

                case .toolResult(let result):
                    dataType = .toolResult
                    payload = AnyCodable(result)

                case .userInputRequest(let request):
                    dataType = .userInputRequest
                    payload = AnyCodable(request)
                    await streamState.setCurrentRunUUID(nil)    // Input-request stops run-loop (to be resumed), can't permit sending "final message" index
                }

                let agentData = AgentData(
                    dataUUID: runUUID,
                    dataIndex: index,
                    agentUUID: response.agentUUID,
                    userUUID: response.userUUID,
                    dataType: dataType,
                    payload: payload
                )

                let response = WSPacket(type: .agentData, payload: AnyCodable(agentData))
                await streamState.incrIndex(for: event.key)
                self.sendTask(response, ws: ws)
            }
        )
        
        if let finalState = await streamState.finalState() {
            sendAgentDataCompleted(
                runUUID: finalState.runUUID,
                lastDataIndex: finalState.lastDataIndex,
                userUUID: response.userUUID,
                agentUUID: response.agentUUID,
                ws: ws
            )
        }
    }
    
    private func handleChatData(_ chatData: ChatData, ws: WebSocket) async {
        guard let dawson = dawson else { return }
        
        switch (chatData.dataType) {
        case .upsert:
            guard let chat: Chat = guardPayload(chatData.payload, dataType: chatData.dataType.rawValue, ws: ws) else { return }
            await dawson.upsertChat(chat)
            
        case .delete:
            guard let chatUUID: String = guardPayload(chatData.payload, dataType: chatData.dataType.rawValue, ws: ws) else { return }
            dawson.deleteChat(chatUUID)
            
        case .syncChat:
            var payload: AnyCodable
            if let chatUUID = chatData.chatUUID {
                guard let chat = dawson.getChat(chatUUID),
                      let encoded = try? JSONEncoder().encode(chat),
                      let json = try? JSONDecoder().decode(AnyCodable.self, from: encoded) else { return }
                payload = json
            } else {
                let chats = dawson.getAllChats(userUUID: chatData.userUUID)
                guard let encoded = try? JSONEncoder().encode(chats),
                      let json = try? JSONDecoder().decode(AnyCodable.self, from: encoded) else { return }
                payload = json
            }
            
            let chatData = ChatData(
                chatUUID: chatData.chatUUID,
                userUUID: chatData.userUUID,
                agentUUID: chatData.agentUUID,
                dataType: .syncChat,
                payload: payload
            )
            let response = WSPacket(type: .chatData, payload: AnyCodable(chatData))
            self.sendTask(response, ws: ws)
            
        case .syncMsgs:
            var payload: AnyCodable
            if let chatUUID = chatData.chatUUID {
                payload = AnyCodable(dawson.getMessagesForChat(chatUUID))
            } else {
                let messages = dawson.getAllMessages(userUUID: chatData.userUUID)
                payload = AnyCodable(messages)
            }
            
            let chatData = ChatData(
                chatUUID: chatData.chatUUID,
                userUUID: chatData.userUUID,
                agentUUID: chatData.agentUUID,
                dataType: .syncMsgs,
                payload: payload
            )
            let response = WSPacket(type: .chatData, payload: AnyCodable(chatData))
            self.sendTask(response, ws: ws)
        }
    }
    
    private func handleConfigData(_ configData: ConfigData, ws: WebSocket) async {
        switch (configData.dataType) {
        case .updateAgent:
            guard let agent: Agent = guardPayload(configData.payload, dataType: configData.dataType.rawValue, ws: ws) else { return }
            AgentHandler.shared.updateAgent(agent: agent)
            
        case .deleteAgent:
            // Unsure yet if/how will allow client to remove agent(s), will need be safeguarded since can break subagents
            break
            
        case .syncAgents:
            var payload: AnyCodable
            var respDataType = configData.dataType
            if let agentUUID = configData.agentUUID {
                payload = AnyCodable(AgentHandler.shared.getAgent(agentUUID))
                respDataType = .updateAgent
            } else if let userUUID = configData.userUUID {
                payload = AnyCodable(AgentHandler.shared.getAgents(userUUID: userUUID))
            } else {
                await send(WSPacket(type: .error, payload: "Missing userUUID to syncAgents (ConfigData)"), ws: ws)
                return
            }
            
            let configData = ConfigData(
                userUUID: configData.userUUID,
                agentUUID: configData.agentUUID,
                providerType: configData.providerType,
                dataType: respDataType,
                payload: payload
            )
            let response = WSPacket(type: .configData, payload: AnyCodable(configData))
            self.sendTask(response, ws: ws)
            
        case .upsertUser:
            guard let user: User = guardPayload(configData.payload, dataType: configData.dataType.rawValue, ws: ws) else { return }
            UserHandler.shared.upsertUser(user)
            
        case .deleteUser:
            guard let userUUID: String = guardPayload(configData.payload, dataType: configData.dataType.rawValue, ws: ws) else { return }
            UserHandler.shared.deleteUser(userUUID)
            
        case .syncUsers:
            var payload: AnyCodable
            var respDataType = configData.dataType
            if let userUUID = configData.userUUID {
                payload = AnyCodable(UserHandler.shared.getUser(userUUID))
                respDataType = .upsertUser
            } else {
                payload = AnyCodable(UserHandler.shared.getUsers())
            }
            
            let configData = ConfigData(
                userUUID: configData.userUUID,
                agentUUID: configData.agentUUID,
                providerType: configData.providerType,
                dataType: respDataType,
                payload: payload
            )
            let response = WSPacket(type: .configData, payload: AnyCodable(configData))
            self.sendTask(response, ws: ws)
            
        case .updateProvider:
            guard let providerAPIKeys: [String: String] = guardPayload(configData.payload, dataType: configData.dataType.rawValue, ws: ws) else { return }
            providerAPIKeys.forEach { providerName, apiKey in
                guard let providerType = ProviderClient.ProviderType(rawValue: providerName) else { return }
                ProviderClient.ProviderType.setAPIKey(providerType, key: apiKey)
            }
            
        case .syncProviders:
            var payload: AnyCodable
            var respDataType = configData.dataType
            if let providerType = configData.providerType {
                payload = await AnyCodable(Provider.getProvider(providerType))
            } else {
                payload = await AnyCodable(Provider.getProviders())
            }
            
            let configData = ConfigData(
                userUUID: configData.userUUID,
                agentUUID: configData.agentUUID,
                providerType: configData.providerType,
                dataType: respDataType,
                payload: payload
            )
            let response = WSPacket(type: .configData, payload: AnyCodable(configData))
            self.sendTask(response, ws: ws)
        }
    }
    
    private func handleSyncState(_ syncState: SyncState, ws: WebSocket) async {
        guard let dawson = dawson else { return }

        let agents = AgentHandler.shared.getAgents(userUUID: syncState.userUUID)
        let agentStates = agents.reduce(into: [String: Int64]()) { states, agent in
            states[agent.uuid] = agent.updatedTimestamp
        }

        let users = UserHandler.shared.getUsers()
        let userStates = users.reduce(into: [String: Int64]()) { states, user in
            states[user.uuid] = user.updatedTimestamp
        }

        let providers = await Provider.getProviders()
        let providerStates = providers.reduce(into: [String: Int64]()) { states, provider in
            states[provider.type.rawValue] = provider.updatedTimestamp
        }

        let chats = dawson.getAllChats(userUUID: syncState.userUUID)
        let chatStates = chats.reduce(into: [String: Int64]()) { states, chat in
            states[chat.uuid] = chat.updatedTimestamp
        }

        let chatMessageStates = chats.reduce(into: [String: Int64]()) { states, chat in
            let newestTimestamp = dawson.getMessagesForChat(chat.uuid)
                .map { $0.timestamp }
                .max() ?? 0

            states[chat.uuid] = newestTimestamp
        }

        let response = SyncState(
            userUUID: syncState.userUUID,
            agentStates: agentStates,
            userStates: userStates,
            providerStates: providerStates,
            chatStates: chatStates,
            chatMessageStates: chatMessageStates
        )

        self.sendTask(WSPacket(type: .syncState, payload: AnyCodable(response)), ws: ws)
    }
}

extension WebSocketServer {
    private func sendAgentDataCompleted(runUUID: String, lastDataIndex: Int32?, userUUID: String, agentUUID: String, ws: WebSocket) {
        let agentData = AgentData(
            dataUUID: runUUID,
            dataIndex: 0,
            agentUUID: agentUUID,
            userUUID: userUUID,
            dataType: .dataLastIndex,
            payload: AnyCodable(lastDataIndex)
        )

        let response = WSPacket(type: .agentData, payload: AnyCodable(agentData))
        self.sendTask(response, ws: ws)
    }
    
    private func guardPayload<T: Decodable>(_ payload: AnyCodable, dataType: String, ws: WebSocket) -> T? {
        guard let data = try? JSONEncoder().encode(payload),
              let object = try? JSONDecoder().decode(T.self, from: data) else {
            sendTask(WSPacket(type: .error, payload: "Invalid \(dataType) payload"), ws: ws)
            return nil
        }
        return object
    }
}

//
//  WebSocketServer.swift
//  
//
//  Created by Ethan Brown on 4/9/26.
//

import Foundation
import Vapor
import AnyCodable

struct WSPacket: Codable {
    let type: PacketType
    let payload: AnyCodable
    
    enum PacketType: String, Codable {
        case ping = "PING"
        case pong = "PONG"
        case userData = "USER_DATA"
        case agentData = "AGENT_DATA"
        case chatData = "CHAT_DATA"
        case configData = "CONFIG_DATA"
        case userInputRequest = "USER_INPUT_REQUEST"
        case userInputRequestResponse = "USER_INPUT_REQUEST_RESPONSE"
        case error = "ERROR"
    }
}

final class WebSocketServer: @unchecked Sendable {

    weak var dawson: DAWSON?
    
    private var connections: [UUID: WebSocket] = [:]

    func handle(_ ws: WebSocket) {
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

    private func onReceive(json: String, ws: WebSocket) async {
        print("raw json received: \(json)")
        guard let data = json.data(using: .utf8),
              let packet: WSPacket = try? JSONDecoder().decode(WSPacket.self, from: data) else { return }
        print("packet: \(packet.payload)")
        
        switch (packet.type) {
        case .ping:
            await send(WSPacket(type: .pong, payload: "pong"), ws: ws)
            
        case .userData:
            guard let payload: UserData = await guardPayload(packet.payload, dataType: packet.type.rawValue, ws: ws) else { return }
            await handleUserData(payload, ws: ws)

        case .chatData:
            guard let payload: ChatData = await guardPayload(packet.payload, dataType: packet.type.rawValue, ws: ws) else { return }
            await handleChatData(payload, ws: ws)
            
        case .userInputRequestResponse:
            guard let payload: UserInputResponse = await guardPayload(packet.payload, dataType: packet.type.rawValue, ws: ws) else { return }
            await handleUserInputResponse(payload, ws: ws)
            
        case .configData:
            guard let payload: ConfigData = await guardPayload(packet.payload, dataType: packet.type.rawValue, ws: ws) else { return }
            await handleConfigData(payload, ws: ws)
            
        default:
            await send(WSPacket(type: .error, payload: "Unknown packet type"), ws: ws)
        }
    }

    private func send(_ message: WSPacket, ws: WebSocket) async {
        guard let data = try? JSONEncoder().encode(message),
              let text = String(data: data, encoding: .utf8) else { return }
        try? await ws.send(text)
    }

    func broadcast(_ message: WSPacket) {
        guard let data = try? JSONEncoder().encode(message),
              let text = String(data: data, encoding: .utf8) else { return }
        for ws in connections.values {
            ws.send(text)
        }
    }
}

extension WebSocketServer {
    
    private func handleUserData(_ userData: UserData, ws: WebSocket) async {
        guard let dawson = dawson else { return }
        switch (userData.dataType) {
        case .textPrompt:
            guard let textPrompt: String = await guardPayload(userData.payload, dataType: userData.dataType.rawValue, ws: ws) else { return }
            
            var dataIndex: [String: Int32] = [:]
            var currentRunUUID: String? = nil
            await dawson.getChatResponse(chatUUID: userData.chatUUID, runUUID: userData.dataUUID, prompt: textPrompt,
                onEvent: { event, runUUID in
                    var dataType: AgentData.DataType
                    var payload: AnyCodable
                    let index = (dataIndex[event.key] ?? 0)
                    currentRunUUID = runUUID
                    
                    switch event {
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
                        currentRunUUID = nil    // Input-request stops run-loop (to be resumed), can't permit sending "final message" index
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
                    dataIndex[event.key] = (index + 1)
                    Task {
                        await self.send(response, ws: ws)
                    }
                }
            )
            
            if let currentRunUUID = currentRunUUID {
                let lastDataIndex: Int32 = (dataIndex[AgentEvent.content().key] ?? 1) - 1
                sendAgentDataCompleted(runUUID: currentRunUUID, lastDataIndex: lastDataIndex, userUUID: userData.userUUID, agentUUID: userData.agentUUID, ws: ws)
            }
        case .dataPrompt:
            break
        }
    }
    
    private func handleUserInputResponse(_ response: UserInputResponse, ws: WebSocket) async {
        guard let dawson = dawson else { return }
        var dataIndex: [String: Int32] = [:]

        var currentRunUUID: String? = nil
        await dawson.getChatResumedResponse(response: response,
            onEvent: { event, runUUID in
                var dataType: AgentData.DataType
                var payload: AnyCodable
                let index = (dataIndex[event.key] ?? 0)
                currentRunUUID = runUUID

                switch event {
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
                    currentRunUUID = nil    // Input-request stops run-loop (to be resumed), can't permit sending "final message" index
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
                dataIndex[event.key] = (index + 1)
                
                Task {
                    await self.send(response, ws: ws)
                }
            }
        )
        
        if let currentRunUUID = currentRunUUID {
            let lastDataIndex: Int32 = (dataIndex[AgentEvent.content().key] ?? 1) - 1
            sendAgentDataCompleted(runUUID: currentRunUUID, lastDataIndex: lastDataIndex, userUUID: response.userUUID, agentUUID: response.agentUUID, ws: ws)
        }
    }
    
    private func handleChatData(_ chatData: ChatData, ws: WebSocket) async {
        guard let dawson = dawson else { return }
        
        switch (chatData.dataType) {
        case .upsert:
            guard let chat: Chat = await guardPayload(chatData.payload, dataType: chatData.dataType.rawValue, ws: ws) else { return }
            dawson.upsertChat(chat)
            
        case .delete:
            guard let chatUUID: String = await guardPayload(chatData.payload, dataType: chatData.dataType.rawValue, ws: ws) else { return }
            dawson.deleteChat(chatUUID)
            
        case .syncChat:
            var payload: AnyCodable
            if let chatUUID = chatData.chatUUID {
                guard let chat = dawson.getChat(chatUUID),
                      let encoded = try? JSONEncoder().encode(chat),
                      let json = try? JSONDecoder().decode(AnyCodable.self, from: encoded) else { return }
                payload = json
            } else {
                let chats = dawson.getAllChats()
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
            Task {
                await self.send(response, ws: ws)
            }
            
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
            Task {
                await self.send(response, ws: ws)
            }
        }
    }
    
    private func handleConfigData(_ configData: ConfigData, ws: WebSocket) async {
        switch (configData.dataType) {
        case .updateAgent:
            guard let agentConfig: AgentConfigData = await guardPayload(configData.payload, dataType: configData.dataType.rawValue, ws: ws) else { return }
            AgentHandler.shared.updateAgent(agentConfig: agentConfig)
            
        case .deleteAgent:
            // Unsure yet if will allow client to remove agent(s), will need be safeguarded since can break subagents
            
        case .upsertUser:
            guard let user: User = await guardPayload(configData.payload, dataType: configData.dataType.rawValue, ws: ws) else { return }
            UserHandler.shared.upsertUser(user)
            
        case .deleteUser:
            guard let userUUID: String = await guardPayload(configData.payload, dataType: configData.dataType.rawValue, ws: ws) else { return }
            UserHandler.shared.deleteUser(userUUID)
        }
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
        Task {
            await self.send(response, ws: ws)
        }
    }
    
    private func guardPayload<T: Decodable>(_ payload: AnyCodable, dataType: String, ws: WebSocket) async -> T? {
        guard let payloadData = try? JSONSerialization.data(withJSONObject: payload.value),
              let object = try? JSONDecoder().decode(T.self, from: payloadData) else {
            await send(WSPacket(type: .error, payload: "Invalid \(dataType) payload"), ws: ws)
            return nil
        }
        return object
    }
}

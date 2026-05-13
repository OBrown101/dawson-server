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
            guard let payloadData = try? JSONSerialization.data(withJSONObject: packet.payload.value),
                  let userData = try? JSONDecoder().decode(UserData.self, from: payloadData) else {
                await send(WSPacket(type: .error, payload: "Invalid USER_DATA payload"), ws: ws)
                return
            }
            print("userdata")
            await handleUserData(userData, ws: ws)
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
        switch (userData.dataType) {
        case .textPrompt:
            guard let textPrompt = userData.payload.value as? String else {
                await send(WSPacket(type: .error, payload: "Invalid \(userData.dataType.rawValue) payload"), ws: ws)
                return
            }
            
            print("textPrompt")
            var dataIndex: [AgentEvent: Int32] = [:]
            if (userData.agentUUID.isEmpty) { return }  // Invalid agentUUID
            
            let _ = await dawson?.run(agentUUID: userData.agentUUID, prompt: textPrompt,
              onEvent: { event, sessionUUID in
                var dataType: AgentData.DataType
                var payload: AnyCodable
                let index = (dataIndex[event] ?? 0)
                
                switch event {
                case .thinking(let text):
                    dataType = .textThinking
                    payload = AnyCodable(text)
                case .content(let text):
                    dataType = .textResponse
                    payload = AnyCodable(text)
                case .toolCall(let name):
                    dataType = .toolCall
                    payload = AnyCodable("Calling tool: \(name)")
                case .toolResult(let result):
                    dataType = .toolResult
                    payload = AnyCodable("Tool result: \(result)")
                }
                
                let agentData = AgentData(dataUUID: sessionUUID,
                                          dataIndex: index,
                                          agentUUID: userData.agentUUID,
                                          userUUID: userData.userUUID,
                                          dataType: dataType,
                                          payload: payload)
                let response = WSPacket(type: .agentData, payload: AnyCodable(agentData))
                dataIndex[event] = (index + 1)
                Task {
                    await self.send(response, ws: ws)
                }
            })
        case .dataPrompt:
            break
        case .agentConfig:
            break
        }
    }
}

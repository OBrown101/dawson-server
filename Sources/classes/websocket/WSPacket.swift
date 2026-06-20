//
//  WSPacket.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/20/26.
//

import Foundation
import AnyCodable

struct WSPacket: Codable, @unchecked Sendable {
    let type: PacketType
    let payload: AnyCodable
    let transferUUID: String?
    let index: Int?
    let total: Int?
    
    init(
        type: PacketType,
        payload: AnyCodable,
        transferUUID: String? = nil,
        index: Int? = nil,
        total: Int? = nil
    ) {
        self.type = type
        self.payload = payload
        self.transferUUID = transferUUID
        self.index = index
        self.total = total
    }
    
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
    
    var isChunk: Bool {
        (transferUUID != nil) && (index != nil) && (total != nil)
    }
}

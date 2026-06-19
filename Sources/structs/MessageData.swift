//
//  MessageData.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/28/26.
//

import Foundation
import AnyCodable

struct MessageData: Codable, Equatable {
    let uuid: String
    let runUUID: String
    let timestamp: Int64
    let chatUUID: String?
    let sourceType: SourceType
    let sourceUUID: String
    let destinationUUID: String
    let dataType: DataType
    let payload: AnyCodable
    
    enum DataType: String, Codable {
        case text = "TEXT"
        case data = "DATA"
    }
    
    enum SourceType: String, Codable {
        case prompt = "PROMPT"
        case response = "RESPONSE"
    }
    
    static func fromMessage(_ message: Message, chatUUID: String?, userUUID: String, agentUUID: String) -> MessageData? {
        // Only stores (permanently) assistant and user messages
        let text = message.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if (text.isEmpty) { return nil }
        
        if ((message.role != MsgSource.user.name) && (message.role != MsgSource.assistant.name)) { return nil }
        
        return MessageData(
            uuid: message.uuid,
            runUUID: message.runUUID,
            timestamp: Int64(message.createdAt.timeIntervalSince1970 * 1000),
            chatUUID: chatUUID,
            sourceType: (message.role == MsgSource.user.name) ? .prompt : .response,
            sourceUUID: (message.role == MsgSource.user.name) ? userUUID : agentUUID,
            destinationUUID: (message.role == MsgSource.user.name) ? agentUUID : userUUID,
            dataType: .text,    // For now, in future will need to handle data from models
            payload: AnyCodable(text)
        )
    }
}

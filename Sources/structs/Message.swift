//
//  Message.swift
//  
//
//  Created by Ethan Brown on 3/22/26.
//

import Foundation

struct Message: Codable, Sendable {
    let uuid: String
    let runUUID: String
    let createdAt: Date
    let model: String
    let role: String
    let text: String?
    let toolCalls: [ToolCall]?
    
    init(uuid: String = UUID().uuidString, runUUID: String, createdAt: Date = Date.now, model: String = "", role: String, text: String?, toolCalls: [ToolCall]? = nil) {
        self.uuid = uuid
        self.runUUID = runUUID
        self.createdAt = createdAt
        self.model = model
        self.role = role
        self.text = text
        self.toolCalls = toolCalls
    }
    
    static func fromProvider(_ providerResponse: ProviderResponse, runUUID: String) -> Message {
        let createdAt = DateHandler.shared.iso8601Formatter.date(from: providerResponse.createdAt) ?? Date.now
        return Message(
            runUUID: runUUID,
            createdAt: createdAt,
            model: providerResponse.model,
            role: MsgSource.assistant.name,
            text: providerResponse.content,
            toolCalls: ToolCall.fromProviderToolJSON(providerResponse.toolCalls))
    }
}

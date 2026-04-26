//
//  Message.swift
//  
//
//  Created by Ethan Brown on 3/22/26.
//

import Foundation

struct Message {
    let createdAt: Date
    let model: String
    let role: String
    let text: String?
    let toolCalls: [ToolCall]?
    
    init(createdAt: Date = Date.now, model: String = "", role: String, text: String?, toolCalls: [ToolCall]? = nil) {
        self.createdAt = createdAt
        self.model = model
        self.role = role
        self.text = text
        self.toolCalls = toolCalls
    }
    
    static func fromProvider(_ providerResponse: ProviderResponse) -> Message {
        let createdAt = DateHandler.shared.iso8601Formatter.date(from: providerResponse.createdAt) ?? Date.now
        return Message(
            createdAt: createdAt,
            model: providerResponse.model,
            role: MsgSource.assistant.name,
            text: providerResponse.content,
            toolCalls: ToolCall.fromOllamaToolJSON(providerResponse.toolCalls))
    }
}

//
//  Message.swift
//  DAWSON
//
//  Created by Ethan Brown on 3/22/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

struct Message: Codable, Sendable {
    let uuid: String
    let runUUID: String
    let originActor: String?
    let createdAt: Date
    let model: String
    let role: String
    let text: String?
    let toolCallId: String?           // Represents ToolCall.id when text is the result from that tool's execution
    let toolCalls: [ToolCall]?
    let attachments: [ImageAttachment]?
    
    init(uuid: String = UUID().uuidString, runUUID: String, originActor: String? = nil, createdAt: Date = Date.now, model: String = "", role: String, text: String?, toolCallId: String? = nil, toolCalls: [ToolCall]? = nil, attachments: [ImageAttachment]? = nil) {
        self.uuid = uuid
        self.runUUID = runUUID
        self.originActor = originActor
        self.createdAt = createdAt
        self.model = model
        self.role = role
        self.text = text
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
        self.attachments = attachments
    }
    
    static func fromProvider(_ providerResponse: ProviderResponse, runUUID: String) -> Message {
        let createdAt = DateHandler.shared.iso8601Formatter.date(from: providerResponse.createdAt) ?? Date.now
        return Message(
            runUUID: runUUID,
            createdAt: createdAt,
            model: providerResponse.model,
            role: MsgSource.assistant.name,
            text: providerResponse.content,
            toolCalls: ToolCall.fromProviderToolJSON(providerType: providerResponse.providerType, providerResponse.toolCalls))
    }
}

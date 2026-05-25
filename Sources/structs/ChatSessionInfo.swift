//
//  ChatSessionInfo.swift
//
//
//  Created by Ethan Brown on 3/19/26.
//

import Foundation

struct ChatSuspendData: Codable {
    let agentUUID: String
    let runUUID: String
    var iterationIndex: Int
    var messages: [Message]
    var userInputRequest: UserInputRequest? = nil
    var toolCalls: [ToolCall]? = nil
    var toolCallIndex: Int = 0
}

struct ChatSessionInfo: Codable {
    let uuid: String
    let userUUID: String
    var mode: ModeType
    var directories: [String] = [DAWSON.root]
    
    var suspendData: ChatSuspendData? = nil
}


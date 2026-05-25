//
//  AgentData.swift
//
//
//  Created by Ethan Brown on 4/25/26.
//

import Foundation
import AnyCodable

struct AgentData: Codable {
    let dataUUID: String    // Used to group text/data chunks
    let dataIndex: Int32    // Used for text/data chunks (keep track of order)
    let agentUUID: String
    let userUUID: String
    let dataType: DataType
    let payload: AnyCodable
    
    enum DataType: String, Codable {
        case textThinking = "TEXT_THINKING"
        case textResponse = "TEXT_RESPONSE"
        case dataResponse = "DATA_RESPONSE"
        case toolCall = "TOOL_CALL"
        case toolResult = "TOOL_RESULT"
        case userInputRequest = "USER_INPUT_REQUEST"
        case error = "ERROR"
    }
}

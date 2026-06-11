//
//  UserInputRequest.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//

import Foundation

struct UserInputRequest: Codable {
    let agentUUID: String
    let userUUID: String
    let type: ReqType
    let prompt: String          // Can be reason for request or LLM's prompt to the user
    let toolCallName: String?
    let metadata: [String: String]
    
    enum ReqType: String, Codable {
        case permission = "PERMISSION"
        case confirmation = "CONFIRMATION"
        case input = "INPUT"
    }
}

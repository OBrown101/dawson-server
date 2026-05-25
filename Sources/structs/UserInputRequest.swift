//
//  UserInputRequest.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//

import Foundation

struct UserInputRequest: Codable {
    let uuid: String
    let type: UserRequestType
    let prompt: String          // Can be reason for request or LLM's prompt to the user
    let toolCallName: String?
    let metadata: [String: String]
    
    enum UserRequestType: String, Codable {
        case permission = "PERMISSION"
        case clarification = "CLARIFICATION"
        case confirmation = "CONFIRMATION"
        case selection = "SELECTION"
        case input = "INPUT"
    }
}

//
//  UserData.swift
//  
//
//  Created by Ethan Brown on 4/25/26.
//

import Foundation
@preconcurrency import AnyCodable

struct UserData: Codable, Sendable {
    let dataUUID: String
    let chatUUID: String
    let agentUUID: String
    let userUUID: String
    let dataType: DataType
    var payload: AnyCodable
    
    enum DataType: String, Codable {
        case textPrompt = "TEXT_PROMPT"
        case dataPrompt = "DATA_PROMPT"
    }
}

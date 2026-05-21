//
//  UserData.swift
//  
//
//  Created by Ethan Brown on 4/25/26.
//

import Foundation
import AnyCodable

struct UserData: Codable {
    let agentUUID: String
    let userUUID: String
    let dataType: DataType
    let payload: AnyCodable
    
    enum DataType: String, Codable {
        case textPrompt = "TEXT_PROMPT"
        case dataPrompt = "DATA_PROMPT"
        case agentConfig = "AGENT_CONFIG"
        case setMode = "SET_MODE"
    }
}

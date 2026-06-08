//
//  ConfigData.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/1/26.
//

import Foundation
import AnyCodable

struct ConfigData: Codable {
    let userUUID: String
    let dataType: DataType
    let payload: AnyCodable
    
    enum DataType: String, Codable {
        case updateAgent = "UPDATE_AGENT"
        case deleteAgent = "DELETE_AGENT"
        case syncAgents = "SYNC_AGENTS"
        case upsertUser = "UPSERT_USER"
        case deleteUser = "DELETE_USER"
        case syncUsers = "SYNC_USERS"
        case updateProvider = "UPDATE_PROVIDER"
        case syncProviders = "SYNC_PROVIDERS"
    }
}

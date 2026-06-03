//
//  AgentConfigData.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/1/26.
//

import Foundation
import AnyCodable

struct AgentConfigData: Codable {
    // Same as Agent class, but only specific data for client
    let agentUUID: String
    let type: Agent.AgentType
    let mode: ModeType
    let model: String
    let directories: [String]
    let updatedTimestamp: Int64
}

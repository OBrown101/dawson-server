//
//  SyncState.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/21/26.
//

import Foundation
import AnyCodable

struct SyncState: Codable {
    let userUUID: String
    let agentStates: [String: Int64]    // (UUID to updatedTimestamp)
    let userStates: [String: Int64]
    let providerStates: [String: Int64]
    let chatStates: [String: Int64]
    let chatMessageStates: [String: Int64]
}

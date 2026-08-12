//
//  UserData.swift
//  DAWSON
//
//  Created by Ethan Brown on 4/25/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
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
        case cancelCmd = "CANCEL_CMD"
    }
}

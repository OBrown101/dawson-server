//
//  ChatData.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/28/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import AnyCodable

struct ChatData: Codable {
    let chatUUID: String?
    let userUUID: String
    let agentUUID: String?
    let dataType: DataType
    let payload: AnyCodable
    
    enum DataType: String, Codable {
        case upsert = "UPSERT_CHAT"
        case delete = "DELETE_CHAT"
        case syncChat = "SYNC_CHAT"
        case syncMsgs = "SYNC_CHAT_MESSAGES"
    }
}

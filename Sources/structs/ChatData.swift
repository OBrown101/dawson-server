//
//  ChatData.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/28/26.
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

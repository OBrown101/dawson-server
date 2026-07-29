//
//  PendingChildSuspension.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/28/26.
//

struct PendingChildSuspension: Codable {
    
    enum Kind: Codable {
        case childRequest   // Running child suspended on permission/confirmation.
        case modeDiscrepancy(pendingMessage: String)    // Pre-flight approval to message user-owned agent outranking orchestrator; outbound message held until approved
    }

    let kind: Kind
    let childChatUUID: String
    let childAgentUUID: String
    let taskTitle: String
    var autoResolvedInputs: [String] = []
}

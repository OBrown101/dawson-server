//
//  PendingChildSuspension.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/28/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

struct PendingChildSuspension: Codable {
    
    enum Kind: Codable {
        case childRequest   // Running child suspended on permission/confirmation.
        case modeDiscrepancy(pendingMessage: String)    // Pre-flight approval to message user-owned agent outranking orchestrator; outbound message held until approved
        case chatCreation(brief: String?, mode: ModeType, directories: [String], title: String)    // Approval to create a user-owned chat
        case workerRelease    // Approval to hand a worker to the user
    }

    let kind: Kind
    let childChatUUID: String
    let childAgentUUID: String
    let taskTitle: String
    var autoResolvedInputs: [String] = []
}

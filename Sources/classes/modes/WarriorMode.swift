//
//  WarriorMode.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

class WarriorMode: Mode {
    static let iterationLimit: Int? = 400
    
    required init() {
        
    }
    
    static func evaluateRequests(_ requests: [PermissionRequest], agent: Agent) -> [PermissionEvaluation] {
        var evaluations: [PermissionEvaluation] = []
        for request in requests {
            switch request.action {
            case .all:
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: request.reason ?? "Permission denied: Full permission access is forbidden in this chat's mode.")))
            case .read, .write:
                evaluations.append(evaluateReadWrite(request, agent: agent))
            case .delegate:
                evaluations.append(PermissionEvaluation(request: request, decision: .allowed))
            case .install:
                evaluations.append(PermissionEvaluation(request: request, decision: .requiresApproval(reason: request.reason ?? "Installing a package, software, etc. permanently alters the shared Python environment and requires your approval.")))
            case .web:
                evaluations.append(evaluateWeb(request, agent: agent))
            case .harness:
                evaluations.append(PermissionEvaluation(request: request, decision: .requiresApproval(reason: request.reason ?? "Modifying the harness affects all future agents and requires your approval.")))
            }
        }
        return evaluations
    }
    
    static func evaluateWeb(_ request: PermissionRequest, agent: Agent) -> PermissionEvaluation {
        if (request.requirement == .deny) {
            return PermissionEvaluation(request: request, decision: .denied(reason: request.reason ?? "Permission denied: Web request refused."))

        }
        
        guard let urlString = request.target else {
            // No target URL means a search: queries only reach search provider (SafeSearch forced), never third-party sites.
            return PermissionEvaluation(request: request, decision: .allowed)
        }
        // Fetches provenance-gated: exact URL (fragment ignored) must appeared in chat:
        // search result, user message, or previously allowed fetch. Never matched on domain alone.
        if (WebProvenance.shared.contains(urlString, agentUUID: agent.uuid)) {
            return PermissionEvaluation(request: request, decision: .allowed)
        } else {
            return PermissionEvaluation(request: request, decision: .requiresApproval(reason: "Fetch \(urlString): this URL has no provenance in this chat (it did not appear in a search result, a user message, or a previously fetched page)."))
        }
    }
    
    static func evaluateReadWrite(_ request: PermissionRequest, agent: Agent) -> PermissionEvaluation {
        guard let path = request.target else {
            return PermissionEvaluation(request: request, decision: .denied(reason: request.reason ?? "Permission denied: Missing \(request.action.rawValue) target path."))
        }
        if (FileUtilities.inSessionDirectories(path: path, directories: agent.effectiveDirectories)) {
            return PermissionEvaluation(request: request, decision: .allowed)
        } else {
            return PermissionEvaluation(request: request, decision: .requiresApproval(reason: request.reason ?? "\(request.action.rawValue.capitalized) outside session workspace: \(path)"))
        }
    }
    
    static func getPermissionDescription(for action: ModeAction) -> String {
        switch action {
        case .all:
            return "Full system access is not permitted in Warrior mode."
        case .read:
            return "Files within your session workspace can be read freely. External reads require approval."
        case .write:
            return "Files within your session workspace can be written freely. External writes are not permitted."
        case .delegate:
            return "Delegating to and messaging other agents is permitted in Warrior mode."
        case .install:
            return "Installing packages, software, etc. permanently changes the shared Python environment, so each install requires your approval in Warrior mode."
        case .web:
            return "Web searches are permitted freely (queries reach only the search provider, SafeSearch forced). Fetches are permitted only for exact URLs that already appeared in this chat — a search result, a user message, or a previously fetched page; any other URL requires approval."
        case .harness:
            return "Changes to the harness affect all future agents, so each requires your approval in Warrior mode."
        }
    }
    
    static func guardRequests(_ requests: [PermissionRequest], agent: Agent) throws {
        for request in requests {
            switch request.action {
            case .all:
                throw ModePermissionError.forbidden
            case .read, .write:
                guard let path = request.target else { break }
                let inDirectories = FileUtilities.inSessionDirectories(path: path, directories: agent.effectiveDirectories)
                guard (inDirectories) else { throw ModePermissionError.forbidden }
            case .delegate, .install, .web, .harness:
                break
            }
        }
    }
}

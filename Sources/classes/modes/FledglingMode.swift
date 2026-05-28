//
//  FledglingMode.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//

import Foundation

class FledglingMode: Mode {
    static let iterationLimit: Int? = 30
    
    required init() {
        
    }
    
    static func evaluateRequests(_ requests: [PermissionRequest], agent: Agent) -> [PermissionEvaluation] {
        var evaluations: [PermissionEvaluation] = []
        for request in requests {
            switch request.action {
            case .all:
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: "Full permission access is forbidden in this chat's mode.")))
            case .read:
                evaluations.append(evaluateRead(request, agent: agent))
            case .write:
                evaluations.append(evaluateWrite(request, agent: agent))
            case .command:
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: "Command execution is forbidden in this chat's current mode.")))
            case .sudo:
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: "Sudo access is forbidden in this chat's current mode.")))
            }
        }
        return evaluations
    }
    
    static func evaluateRead(_ request: PermissionRequest, agent: Agent) -> PermissionEvaluation {
        guard let path = request.target else {
            return PermissionEvaluation(request: request, decision: .denied(reason: "Missing read target path."))
        }
        if (Utility.inSessionDirectories(path: path, directories: agent.directories)) {
            return PermissionEvaluation(request: request, decision: .allowed)
        } else {
            return PermissionEvaluation(request: request, decision: .requiresApproval(reason: "Read outside session workspace: \(path)"))
        }
    }
    
    static func evaluateWrite(_ request: PermissionRequest, agent: Agent) -> PermissionEvaluation {
        guard let path = request.target else {
            return PermissionEvaluation(request: request, decision: .denied(reason: "Missing write target path."))
        }

        if (Utility.inSessionDirectories(path: path, directories: agent.directories)) {
            return PermissionEvaluation(request: request, decision: .requiresApproval(reason: "Write operation requires user approval: \(path)"))
        } else {
            return PermissionEvaluation(request: request, decision: .denied(reason: "Writes outside workspace are forbidden."))
        }
    }
    
    static func getPermissionDescription(for action: ModeAction) -> String {
        switch action {
        case .all:
            return ""
        case .read:
            return ""
        case .write:
            return ""
        case .command:
            return ""
        case .sudo:
            return ""
        }
    }
    
    static func guardRequests(_ requests: [PermissionRequest], agent: Agent) throws {
        for request in requests {
            switch request.action {
            case .all:
                throw ModePermissionError.forbidden
            case .read, .write:
                guard let path = request.target else { break }
                let inDirectories = Utility.inSessionDirectories(path: path, directories: agent.directories)
                guard (inDirectories) else { throw ModePermissionError.forbidden }
            case .command:
                throw ModePermissionError.forbidden
            case .sudo:
                throw ModePermissionError.forbidden
            }
        }
    }
}

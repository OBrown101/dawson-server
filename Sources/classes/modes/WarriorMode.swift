//
//  FledglingMode.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//

import Foundation

class WarriorMode: Mode {
    static let iterationLimit: Int? = 50
    
    required init() {
        
    }
    
    static func evaluateRequests(_ requests: [PermissionRequest], agent: Agent) -> [PermissionEvaluation] {
        var evaluations: [PermissionEvaluation] = []
        for request in requests {
            switch request.action {
            case .all:
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: "Permission denied: Full permission access is forbidden in this chat's mode.")))
            case .read, .write:
                evaluations.append(evaluateReadWrite(request, agent: agent))
            case .command:
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: "Permission denied: Command execution is forbidden in this chat's current mode.")))
            case .sudo:
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: "Permission denied: Sudo access is forbidden in this chat's current mode.")))
            }
        }
        return evaluations
    }
    
    static func evaluateReadWrite(_ request: PermissionRequest, agent: Agent) -> PermissionEvaluation {
        guard let path = request.target else {
            return PermissionEvaluation(request: request, decision: .denied(reason: "Permission denied: Missing \(request.action.rawValue) target path."))
        }
        return PermissionEvaluation(request: request, decision: .allowed)
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
                let inDirectories = FileUtilities.inSessionDirectories(path: path, directories: agent.directories)
                guard (inDirectories) else { throw ModePermissionError.forbidden }
            case .command:
                throw ModePermissionError.forbidden
            case .sudo:
                throw ModePermissionError.forbidden
            }
        }
    }
}

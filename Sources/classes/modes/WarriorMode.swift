//
//  WarriorMode.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
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
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: "Permission denied: Full permission access is forbidden in this chat's mode.")))
            case .read, .write:
                evaluations.append(evaluateReadWrite(request, agent: agent))
            case .command:
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: "Permission denied: Command execution is forbidden in this chat's current mode.")))
            case .sudo:
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: "Permission denied: Sudo access is forbidden in this chat's current mode.")))
            case .delegate:
                evaluations.append(PermissionEvaluation(request: request, decision: .allowed))
            case .install:
                evaluations.append(PermissionEvaluation(request: request, decision: .requiresApproval(reason: "Installing a package, software, etc. permanently alters the shared Python environment and requires your approval.")))
            case .web:
                evaluations.append(PermissionEvaluation(request: request, decision: .allowed))
            case .harness:
                evaluations.append(PermissionEvaluation(request: request, decision: .requiresApproval(reason: "Modifying the harness affects all future agents and requires your approval.")))
            }
        }
        return evaluations
    }
    
    static func evaluateReadWrite(_ request: PermissionRequest, agent: Agent) -> PermissionEvaluation {
        guard let path = request.target else {
            return PermissionEvaluation(request: request, decision: .denied(reason: "Permission denied: Missing \(request.action.rawValue) target path."))
        }
        if (FileUtilities.inSessionDirectories(path: path, directories: agent.effectiveDirectories)) {
            return PermissionEvaluation(request: request, decision: .allowed)
        } else {
            return PermissionEvaluation(request: request, decision: .requiresApproval(reason: "\(request.action.rawValue.capitalized) outside session workspace: \(path)"))
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
        case .command:
            return "Command execution is not permitted in Warrior mode."
        case .sudo:
            return "Elevated privileges are not permitted in Warrior mode."
        case .delegate:
            return "Delegating to and messaging other agents is permitted in Warrior mode."
        case .install:
            return "Installing packages, software, etc. permanently changes the shared Python environment, so each install requires your approval in Warrior mode."
        case .web:
            return "Web access is permitted in Warrior mode."
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
            case .command:
                throw ModePermissionError.forbidden
            case .sudo:
                throw ModePermissionError.forbidden
            case .delegate:
                break
            case .install:
                break
            case .web:
                break
            case .harness:
                break
            }
        }
    }
}

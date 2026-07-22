//
//  EggMode.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//

import Foundation

class EggMode: Mode {
    static let iterationLimit: Int? = nil
    
    required init() {
        
    }
    
    static func evaluateRequests(_ requests: [PermissionRequest], agent: Agent) -> [PermissionEvaluation] {
        var evaluations: [PermissionEvaluation] = []
        for request in requests {
            switch request.action {
            case .all:
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: "Permission denied: Full permission access is forbidden in this chat's mode.")))
            case .read:
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: "Permission denied: Reading files is forbidden in this chat's current mode.")))
            case .write:
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: "Permission denied: Writing to files is forbidden in this chat's current mode.")))
            case .command:
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: "Permission denied: Command execution is forbidden in this chat's current mode.")))
            case .sudo:
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: "Permission denied: Sudo access is forbidden in this chat's current mode.")))
            case .delegate:
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: "Permission denied: Delegating to or messaging other agents is forbidden in this chat's current mode.")))
            case .install:
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: "Permission denied: Installing packages, software, etc. is forbidden in this chat's current mode.")))
            case .web:
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: "Permission denied: Web access is forbidden in this chat's current mode.")))
            case .harness:
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: "Permission denied: Modifying the harness is forbidden in this chat's current mode.")))
            }
        }
        return evaluations
    }
    
    static func getPermissionDescription(for action: ModeAction) -> String {
        switch action {
        case .all:
            return "Full system access is not permitted in Egg mode."
        case .read:
            return "File reading is not permitted in Egg mode."
        case .write:
            return "File writing is not permitted in Egg mode."
        case .command:
            return "Command execution is not permitted in Egg mode."
        case .sudo:
            return "Elevated privileges are not permitted in Egg mode."
        case .delegate:
            return "Delegating to or messaging other agents is not permitted in Egg mode."
        case .install:
            return "Installing Python packages, software, etc. is not permitted in Egg mode."
        case .web:
            return "Web access is not permitted in Egg mode."
        case .harness:
            return "Modifying the harness (e.g. promoting shared tools) is not permitted in Egg mode."
        }
    }
    
    static func guardRequests(_ requests: [PermissionRequest], agent: Agent) throws {
        for request in requests {
            switch request.action {
            case .all, .read, .write, .command, .sudo, .delegate, .install, .web, .harness:
                throw ModePermissionError.forbidden
            }
        }
    }
}

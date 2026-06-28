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
        }
    }
    
    static func guardRequests(_ requests: [PermissionRequest], agent: Agent) throws {
        for request in requests {
            switch request.action {
            case .all:
                throw ModePermissionError.forbidden
            case .read:
                throw ModePermissionError.forbidden
            case .write:
                throw ModePermissionError.forbidden
            case .command:
                throw ModePermissionError.forbidden
            case .sudo:
                throw ModePermissionError.forbidden
            }
        }
    }
}

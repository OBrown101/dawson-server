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
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: "Full permission access is forbidden in this chat's mode.")))
            case .read:
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: "Reading files is forbidden in this chat's current mode.")))
            case .write:
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: "Writing to files is forbidden in this chat's current mode.")))
            case .command:
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: "Command execution is forbidden in this chat's current mode.")))
            case .sudo:
                evaluations.append(PermissionEvaluation(request: request, decision: .denied(reason: "Sudo access is forbidden in this chat's current mode.")))
            }
        }
        return evaluations
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

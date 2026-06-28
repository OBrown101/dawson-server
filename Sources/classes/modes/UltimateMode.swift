//
//  FledglingMode.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//

import Foundation

class UltimateMode: Mode {
    static let iterationLimit: Int? = nil
    
    required init() {
        
    }
    
    static func evaluateRequests(_ requests: [PermissionRequest], agent: Agent) -> [PermissionEvaluation] {
        var evaluations: [PermissionEvaluation] = []
        for request in requests {
            evaluations.append(PermissionEvaluation(request: request, decision: .allowed))
        }
        return evaluations
    }
    
    static func getPermissionDescription(for action: ModeAction) -> String {
        switch action {
        case .all:
            return "Full system access is unrestricted in Ultimate mode."
        case .read:
            return "File reading is unrestricted in Ultimate mode."
        case .write:
            return "File writing is unrestricted in Ultimate mode."
        case .command:
            return "Command execution is unrestricted in Ultimate mode."
        case .sudo:
            return "Elevated privileges are unrestricted in Ultimate mode."
        }
    }
    
    static func guardRequests(_ requests: [PermissionRequest], agent: Agent) throws {
        for request in requests {
            switch request.action {
            case .all:
                break
            case .read:
                break
            case .write:
                break
            case .command:
                break
            case .sudo:
                break
            }
        }
    }
}

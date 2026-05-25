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
    
    static func evaluateRequests(_ requests: [PermissionRequest], session: ChatSessionInfo) -> [PermissionEvaluation] {
        var evaluations: [PermissionEvaluation] = []
        for request in requests {
            evaluations.append(PermissionEvaluation(request: request, decision: .allowed))
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
    
    static func guardRequests(_ requests: [PermissionRequest], session: ChatSessionInfo) throws {
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

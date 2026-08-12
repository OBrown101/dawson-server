//
//  FledglingMode.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
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
        case .delegate:
            return "Delegating to and messaging other agents is unrestricted in Ultimate mode."
        case .install:
            return "Installing Python packages, software, etc. is unrestricted in Ultimate mode."
        case .web:
            return "Web access is unrestricted in Ultimate mode."
        case .harness:
            return "Modifying the harness is unrestricted in Ultimate mode."
        }
    }
    
    static func guardRequests(_ requests: [PermissionRequest], agent: Agent) throws {
        for request in requests {
            switch request.action {
            case .all, .read, .write, .delegate, .install, .web, .harness:
                break
            }
        }
    }
}

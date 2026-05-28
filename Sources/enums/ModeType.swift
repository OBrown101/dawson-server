//
//  ModeType.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//

import Foundation

enum ModeType: String, Codable {
    case egg = "EGG"
    case fledgling = "FLEDGLING"
    case warrior = "WARRIOR"
    case ultimate = "ULTIMATE"
}

extension ModeType {
    var modeClass: Mode.Type {
        switch self {
        case .egg: EggMode.self
        case .fledgling: FledglingMode.self
        case .warrior: WarriorMode.self
        case .ultimate: UltimateMode.self
        }
    }

    var iterationLimit: Int? {
        modeClass.iterationLimit
    }

    func permissionDescription(for action: ModeAction) -> String {
        modeClass.getPermissionDescription(for: action)
    }

    func getMode() -> Mode {
        modeClass.init()
    }
    
    func evaluateRequests(_ requests: [PermissionRequest], agent: Agent) -> [PermissionEvaluation] {
        return modeClass.evaluateRequests(requests, agent: agent)
    }

    func guardRequests(_ requests: [PermissionRequest], agent: Agent) throws {
        try modeClass.guardRequests(requests, agent: agent)
    }
    
    func guardRequest(_ request: PermissionRequest, agent: Agent) throws {
        try guardRequests([request], agent: agent)
    }
}

//
//  ModeType.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//

import Foundation

enum ModeType: String, Codable {
    case egg
    case fledgling
    case warrior
    case ultimate
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
    
    func evaluateRequests(_ requests: [PermissionRequest], session: ChatSessionInfo) -> [PermissionEvaluation] {
        return modeClass.evaluateRequests(requests, session: session)
    }

    func guardRequests(_ requests: [PermissionRequest], session: ChatSessionInfo) throws {
        try modeClass.guardRequests(requests, session: session)
    }
    
    func guardRequest(_ request: PermissionRequest, session: ChatSessionInfo) throws {
        try guardRequests([request], session: session)
    }
}

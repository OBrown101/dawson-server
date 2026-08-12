//
//  ModeType.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

enum ModeType: String, Codable, CaseIterable {
    case egg = "EGG"
    case fledgling = "FLEDGLING"
    case warrior = "WARRIOR"
    case ultimate = "ULTIMATE"
    
    static func fromName(_ name: String) -> ModeType? {
        return ModeType.allCases.first(where: { $0.rawValue == name })
    }
    
    var rank: Int {
        switch self {
        case .egg: return 0
        case .fledgling: return 1
        case .warrior: return 2
        case .ultimate: return 3
        }
    }

    static func lower(of a: ModeType, _ b: ModeType) -> ModeType {
        return (a.rank <= b.rank) ? a : b
    }
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

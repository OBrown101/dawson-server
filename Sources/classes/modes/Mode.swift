//
//  Mode.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

protocol Mode {
    init()
    static var iterationLimit: Int? { get }
    static func getPermissionDescription(for action: ModeAction) -> String
    static func evaluateRequests(_ requests: [PermissionRequest], agent: Agent) -> [PermissionEvaluation]
    static func guardRequests(_ requests: [PermissionRequest], agent: Agent) throws
}

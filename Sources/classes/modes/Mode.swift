//
//  Mode.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//

import Foundation

protocol Mode {
    init()
    static var iterationLimit: Int? { get }
    static func getPermissionDescription(for action: ModeAction) -> String
    static func evaluateRequests(_ requests: [PermissionRequest], session: ChatSessionInfo) -> [PermissionEvaluation]
    static func guardRequests(_ requests: [PermissionRequest], session: ChatSessionInfo) throws
}

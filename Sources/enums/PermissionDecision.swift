//
//  PermissionDecision.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//

import Foundation

enum PermissionDecision {
    case allowed
    case requiresApproval(reason: String)
    case denied(reason: String)
}

//
//  PermissionDecision.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

enum PermissionDecision {
    case allowed
    case requiresApproval(reason: String)
    case denied(reason: String)
}

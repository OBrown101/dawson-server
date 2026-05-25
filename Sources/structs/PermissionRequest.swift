//
//  PermissionRequest.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//

import Foundation

enum PermissionRequirement: Codable {
    case automatic
    case userApproval
}

struct PermissionRequest: Codable {
    let action: ModeAction
    var target: String? = nil
    var requirement: PermissionRequirement = .automatic
    var reason: String? = nil
}

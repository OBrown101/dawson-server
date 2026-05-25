//
//  PermissionAware.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//

import Foundation

protocol PermissionAware: Tool {
    func permissionRequests(args: [String: Any]) -> [PermissionRequest]
}

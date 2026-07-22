//
//  SandboxError.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/21/26.
//

import Foundation

enum SandboxError: LocalizedError {
    case unsupportedPlatform
    case sandboxUnavailable(String)
    case setupFailed(String)

    var description: String {
        switch self {
        case .unsupportedPlatform:
            return "Sandboxed execution is not supported on this platform"
        case .sandboxUnavailable(let msg):
            return "Sandbox unavailable (refusing to run unsandboxed): \(msg)"
        case .setupFailed(let msg):
            return "Sandbox setup failed: \(msg)"
        }
    }
}

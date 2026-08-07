//
//  MCPProcessError.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/6/26.
//

import Foundation

enum MCPProcessError: Error {
    case launchFailed(String)
    case notRunning
    case timeout(String)
    case badResponse(String)

    var description: String {
        switch self {
        case .launchFailed(let m): return "MCP launch failed: \(m)"
        case .notRunning: return "MCP server not running"
        case .timeout(let m): return "MCP request timed out: \(m)"
        case .badResponse(let m): return "MCP bad response: \(m)"
        }
    }
}

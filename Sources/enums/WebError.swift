//
//  WebError.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/26/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

enum WebError: Error, LocalizedError {
    case searchUnavailable(String)
    case requestFailed(String)
    case blocked(String)

    var description: String {
        switch self {
        case .searchUnavailable(let m):
            return "Web search is unavailable: \(m)"
        case .requestFailed(let m):
            return "Web request failed: \(m)"
        case .blocked(let m):
            return "Blocked: \(m)"
        }
    }
}

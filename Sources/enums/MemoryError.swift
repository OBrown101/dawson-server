//
//  MemoryError.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/3/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

enum MemoryError: Error {
    case pythonFailed(String)
    case badResponse(String)

    var description: String {
        switch self {
        case .pythonFailed(let msg): return "MemPalace call failed: \(msg)"
        case .badResponse(let msg):  return "MemPalace bad response: \(msg)"
        }
    }
}

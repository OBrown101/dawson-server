//
//  ModeAction.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//

import Foundation

enum ModeAction: String, Codable {
    case all
    case read
    case write
    case delegate
    case install
    case web
    case harness
}

enum ModePermissionError: Error, LocalizedError {
    case forbidden

    var errorDescription: String? {
        switch self {
        case .forbidden:
            return "Permission denied for this operation based on user's chat mode."
        }
    }
}

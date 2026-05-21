//
//  Mode.swift
//
//
//  Created by Ethan Brown on 5/20/26.
//

import Foundation

enum ModeAction: String, Codable {
    case read
    case write
    case command
    case sudo
}

enum Mode: String, Codable {
    case egg
    case fledgling
    case warrior
    case ultimate

    var canRead: Bool {
        switch self {
        case .egg:
            return false
        default:
            return true
        }
    }
    
    var canWrite: Bool {
        switch self {
        case .egg:
            return false
        case .fledgling:
            return true
        case .warrior, .ultimate:
            return true
        }
    }
    
    var canCommands: Bool {
        switch self {
        case .egg:
            return false
        case .fledgling:
            return false
        case .warrior, .ultimate:
            return true
        }
    }

    var canSudo: Bool {
        return (self == .ultimate)
    }

    // Iteration limit for the agent loop (unsure if will utilize this)
    var iterationLimit: Int? {
        switch self {
        case .warrior:
            return 50
        default:
            return nil
        }
    }
}


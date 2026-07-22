//
//  CommandClassifier.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/22/26.
//

import Foundation

enum CommandClass {
    case read
    case write
    case prompt     // Unrecognized, user approval, then sandboxed
    case denied(reason: String)
}

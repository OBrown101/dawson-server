//
//  CommandClassifier.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/22/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

enum CommandClass {
    case read
    case write
    case prompt     // Unrecognized, user approval, then sandboxed
    case denied(reason: String)
}

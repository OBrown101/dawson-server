//
//  SkillMetadata.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/20/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

struct SkillMetadata: Sendable, Codable {
    let name: String
    let description: String
    let directoryPath: String   // To specific skill folder
    
    var skillFilePath: String { // To SKILL.md file
        return URL(fileURLWithPath: directoryPath).appendingPathComponent("SKILL.md").path
    }
}

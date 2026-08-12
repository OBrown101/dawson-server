//
//  UserInputResponse.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

struct UserInputResponse: Codable {
    let agentUUID: String
    let userUUID: String
    let accepted: Bool?
    let responseText: String?
}

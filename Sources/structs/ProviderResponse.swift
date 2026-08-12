//
//  ProviderResponse.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/25/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

struct ProviderResponse {
    var createdAt: String
    var providerType: ProviderClient.ProviderType
    var model: String
    var content: String
    var thinking: String = ""
    var toolCalls: [[String: Any]] = []
    var totalElapsedSec: Int = 0
    var error: Error? = nil
}

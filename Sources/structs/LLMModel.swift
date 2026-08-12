//
//  LLMModel.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/25/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

struct LLMModel: Codable, Identifiable {
    var id: String
    var name: String
    var provider: ProviderClient.ProviderType
}

//
//  ProviderConfigData.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/7/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

struct ProviderConfigData: Codable {
    let type: ProviderClient.ProviderType
    let apiKey: String
}

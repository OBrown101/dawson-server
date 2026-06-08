//
//  ProviderConfigData.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/7/26.
//

import Foundation

struct ProviderConfigData: Codable {
    let type: ProviderClient.ProviderType
    let apiKey: String
}

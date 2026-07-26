//
//  ProviderResponse.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/25/26.
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

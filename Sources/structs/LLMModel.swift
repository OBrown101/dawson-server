//
//  LLMModel.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/25/26.
//

struct LLMModel: Codable, Identifiable {
    var id: String
    var name: String
    var provider: ProviderClient.ProviderType
}

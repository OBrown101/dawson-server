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
    var contextTokens: Int32?
    
    private static let conservativeDefault: Int32 = 128_000
    
    private static let knownContextTokens: [(prefix: String, tokens: Int32)] = [
        // Require updating for new models
        
        // Anthropic
        ("claude-", 200_000),
        // OpenAI (API + Codex OAuth)
        ("gpt-6", 256_000),
        ("gpt-5", 256_000),
        ("gpt-4.1", 1_000_000),
        ("gpt-4o", 128_000),
        ("o3", 200_000),
        ("o4", 200_000),
    ]
    
    var resolvedContextTokens: Int32 {
        if let explicit = contextTokens,
           (explicit > 0) { return explicit }
        
        let match = LLMModel.knownContextTokens
            .filter { id.hasPrefix($0.prefix) }
            .max { $0.prefix.count < $1.prefix.count }
        return match?.tokens ?? LLMModel.conservativeDefault
    }
}

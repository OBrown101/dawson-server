//
//  LLMProvider.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/25/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

protocol LLMProvider {
    static func fetchModels(useOAuth: Bool) async throws -> [LLMModel]
    
    func send(
        messages: [Message],
        model: LLMModel,
        tools: [Tool],
        useThinking: Bool,
        contextWindow: Int32,
        onUpdate: @Sendable @escaping (ProviderResponse) async -> Void
    ) async -> ProviderResponse
}

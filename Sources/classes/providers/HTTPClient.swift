//
//  LLMClient.swift
//  DAWSON
//
//  Created by Ethan Brown on 3/22/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

final class ProviderClient: Sendable {
    static let shared = ProviderClient()
    
    static let oauthSessionId = UUID().uuidString
    
    enum ProviderType: String, Codable, CaseIterable {
        case ollama = "OLLAMA"
        case openai = "OPENAI"
        case anthropic = "ANTHROPIC"

        var url: String {
            switch self {
            case .ollama:
                return "http://localhost:11434/api/chat"
            case .openai:
                return "https://api.openai.com/v1/responses"
            case .anthropic:
                return "https://api.anthropic.com/v1/messages"
            }
        }
        
        var modelUrl: String {
            switch self {
            case .ollama:
                return "http://localhost:11434/api/tags"
            case .openai:
                return "https://api.openai.com/v1/models"
            case .anthropic:
                return "https://api.anthropic.com/v1/models"
            }
        }
        
        var supportsOAuth: Bool {
            switch self {
            case .ollama:
                return false
            case .openai:
                return true
            case .anthropic:
                return false
            }
        }
        
        var apiKey: String? {
            return ProviderHandler.shared.getAPIKey(self)
        }
        
        func fetchModels(useOAuth: Bool) async throws -> [LLMModel] {
            let oauth = (!supportsOAuth) ? false : useOAuth
            switch self {
            case .ollama:
                return try await OllamaProvider.fetchModels(useOAuth: oauth)
            case .openai:
                return try await OpenAIProvider.fetchModels(useOAuth: oauth)
            case .anthropic:
                return try await AnthropicProvider.fetchModels(useOAuth: oauth)
            }
        }
    }
    
    func streamJSON(llmType: ProviderType, payload: [String: Any]) -> AsyncThrowingStream<Data, Error> {
        let payloadData: Data
        do {
            payloadData = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            return AsyncThrowingStream { @Sendable continuation in
                continuation.finish(throwing: error)
            }
        }
        
        return AsyncThrowingStream { @Sendable continuation in
            let task = Task {
                do {
                    guard let url = URL(string: llmType.url) else {
                        throw NSError(domain: "LLMClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                    }
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    switch (llmType) {
                    case .openai:
                        // Eventually should have a switch (in Beakshield) allow user turn off provider
                        if (OpenAIOAuth.shared.isRouting) {
                            // ChatGPT subscription mode → Codex backend
                            guard let codexURL = URL(string: OpenAIOAuth.codexEndpointURL) else {
                                throw NSError(domain: "LLMClient", code: -5, userInfo: [NSLocalizedDescriptionKey: "Invalid Codex endpoint URL"])
                            }
                            let tokens = try await OpenAIOAuth.shared.validAccessToken()
                            request.url = codexURL
                            request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
                            request.setValue(tokens.accountId, forHTTPHeaderField: "chatgpt-account-id")
                            request.setValue("responses=experimental", forHTTPHeaderField: "OpenAI-Beta")
                            request.setValue("codex_cli_rs", forHTTPHeaderField: "originator")
                            request.setValue(ProviderClient.oauthSessionId, forHTTPHeaderField: "session_id")
                        } else if let key = llmType.apiKey,
                                  (!key.isEmpty) {
                            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                        } else {
                            throw NSError(domain: "LLMClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing OpenAI API key and no OAuth available."])
                        }
                        
                    case .anthropic:
                        guard let key = llmType.apiKey,
                                (!key.isEmpty) else {
                               throw NSError(domain: "LLMClient", code: -3, userInfo: [NSLocalizedDescriptionKey: "Missing Anthropic API key"])
                           }

                           request.setValue(key, forHTTPHeaderField: "x-api-key")
                           request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                        
                    default:
                        break
                    }
                    
                    request.httpBody = payloadData
                    
                    let sessionConfig = URLSessionConfiguration.default
                    sessionConfig.timeoutIntervalForRequest = 800
                    sessionConfig.timeoutIntervalForResource = 800
                    let session = URLSession(configuration: sessionConfig)
                    
                    let (bytes, response) = try await session.bytes(for: request)

                    if let httpResponse = response as? HTTPURLResponse,
                       !(200...299).contains(httpResponse.statusCode) {

                        var body = ""
                        for try await line in bytes.lines {
                            if !body.isEmpty {
                                body += "\n"
                            }
                            body += line
                        }

                        throw getHTTPError(domain: "LLMClient", response: httpResponse, body: body)
                    }
                    
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        
                        if ((llmType == .openai) || (llmType == .anthropic)) {
                            guard line.hasPrefix("data: ") else { continue }

                            let jsonString = String(line.dropFirst(6))
                            if jsonString == "[DONE]" { break }

                            guard let data = jsonString.data(using: .utf8) else { continue }
                            continuation.yield(data)
                        } else {
                            guard let data = line.data(using: .utf8) else { continue }
                            
                            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                let jsonData = try JSONSerialization.data(withJSONObject: json)
                                continuation.yield(jsonData)
                                
                                // Detects completion for Ollama providers (needs handling for other provider types)
                                if let done = json["done"] as? Bool,
                                   (done) {
                                    break
                                }
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
                
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    func fetchJSON(llmType: ProviderType) async throws -> [String: Any] {
        guard let url = URL(string: llmType.modelUrl) else {
            throw NSError(domain: "LLMClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        switch llmType {
        case .openai:
            guard let key = llmType.apiKey,
                  (!key.isEmpty) else {
                throw NSError(domain: "LLMClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing OpenAI API key"])
            }

            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        case .anthropic:
            guard let key = llmType.apiKey,
                  (!key.isEmpty) else {
                throw NSError(domain: "LLMClient", code: -3, userInfo: [NSLocalizedDescriptionKey: "Missing Anthropic API key"])
            }

            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        case .ollama:
            break
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw getHTTPError(domain: "LLMClient", response: httpResponse, body: body)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "LLMClient", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
        }

        return json
    }
    
    private func getHTTPError(domain: String, response: HTTPURLResponse, body: String = "") -> NSError {
        return NSError(
            domain: "LLMClient",
            code: response.statusCode,
            userInfo:  [
                NSLocalizedDescriptionKey: body.isEmpty
                    ? "HTTP \(response.statusCode)"
                    : "HTTP \(response.statusCode): \(body)"
            ]
        )

    }
}

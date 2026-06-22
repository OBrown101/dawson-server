//
//  LLMClient.swift
//  
//
//  Created by Ethan Brown on 3/22/26.
//

import Foundation

final class ProviderClient: Sendable {
    static let shared = ProviderClient()
    
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
        
        var apiKey: String? {
            let apiKeys = ServerSettings.shared.providerAPIKeys
            return apiKeys[self]
        }
        
        static func setAPIKey(_ type: ProviderType, key: String) {
            ServerSettings.shared.providerAPIKeys[type] = key
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
                        throw getHTTPError(domain: "LLMClient", response: httpResponse)
                    }
                    
                    for try await line in bytes.lines {
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

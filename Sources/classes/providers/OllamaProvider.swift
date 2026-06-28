//
//  OllamaProvider.swift
//  
//
//  Created by Ethan Brown on 4/18/26.
//

import Foundation

final class OllamaProvider: LLMProvider {
    func send(
        messages: [Message],
        model: LLMModel,
        tools: [Tool],
        useThinking: Bool,
        contextWindow: Int32,
        onUpdate: @Sendable @escaping (ProviderResponse) async -> Void
    ) async -> ProviderResponse {
        var response = ProviderResponse(createdAt: "", model: model.name, content: "")
        
        var payload: [String: Any] = [
            "model": model.name,
            "messages": messages.map {[
                "role": $0.role,
                "content": $0.text
            ]},
            "thinking": useThinking,
            "options": [
                "num_ctx": contextWindow
            ]
        ]
        
        if (!tools.isEmpty) {
            payload["tools"] = tools.map { $0.ollamaSchema() }
            payload["tool_choice"] = "auto"
        }
        
        do {
            try Task.checkCancellation()
            let stream = ProviderClient.shared.streamJSON(llmType: .ollama, payload: payload)
            
            for try await jsonData in stream {
                try Task.checkCancellation()
                
                guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { return response }
                
                var chunkResponse = ProviderResponse(createdAt: "", model: "", content: "")
                
                if let created = json["createdAt"] as? String {
                    chunkResponse.createdAt = created
                    response.createdAt = created
                }
                if let model = json["model"] as? String {
                    chunkResponse.model = model
                    response.model = model
                }
                
                if let message = json["message"] as? [String: Any] {
                    // Detect tool calls (Ollama-style)
                    if let toolCalls = message["tool_calls"] as? [[String: Any]] {
                        response.toolCalls.append(contentsOf: toolCalls)
                    }
                    
                    // Handle streamed content
                    let thinking = message["thinking"] as? String
                    let content = message["content"] as? String
                    
                    if let t = thinking {
                        chunkResponse.thinking = t
                        response.thinking += t
                    }
                    if let c = content {
                        chunkResponse.content = c
                        response.content += c
                    }
                    
                    if Task.isCancelled { throw CancellationError() }
                    
                    if (content != nil || thinking != nil) {
                        await onUpdate(chunkResponse)
                    }
                }
            }
        } catch is CancellationError {
            return ProviderResponse(createdAt: "", model: model.name, content: "")
        } catch {
            print("Provider error:", error)
            var errorResponse = response
            errorResponse.error = error
        }
        return response
    }
    
    func fetchModels() async throws -> [LLMModel] {
        let json = try await ProviderClient.shared.fetchJSON(llmType: .ollama)

        guard let models = json["models"] as? [[String: Any]] else {
            return []
        }

        let llmModels = models.compactMap { model -> LLMModel? in
            guard let name = model["name"] as? String else { return nil }
            return LLMModel(id: name, name: name, provider: .ollama)
        }
        return llmModels
    }
}

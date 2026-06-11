//
//  OpenAIProvider.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/7/26.
//

import Foundation

final class OpenAIProvider: LLMProvider {
    func send(
        messages: [Message],
        model: LLMModel,
        tools: [Tool],
        useThinking: Bool,
        contextWindow: Int32,
        onUpdate: @escaping (ProviderResponse) -> Void
    ) async -> ProviderResponse {
        var response = ProviderResponse(createdAt: "", model: model.name, content: "")

        var payload: [String: Any] = [
            "model": model.id,
            "input": messages.map {
                [
                    "role": $0.role,
                    "content": $0.text
                ]
            },
            "stream": true
        ]
        
        if (useThinking) {
            payload["reasoning"] = [
                "effort": "medium"
            ]
        }

        if !tools.isEmpty {
            payload["tools"] = tools.map { $0.openAISchema() }
            payload["tool_choice"] = "auto"
        }

        do {
            let stream = ProviderClient.shared.streamJSON(
                llmType: .openai,
                payload: payload
            )

            for try await jsonData in stream {
                guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let type = json["type"] as? String else {
                    continue
                }

                var chunkResponse = ProviderResponse(createdAt: "", model: model.name, content: "")

                switch type {
                case "response.output_text.delta":
                    if let delta = json["delta"] as? String {
                        chunkResponse.content = delta
                        response.content += delta
                        onUpdate(chunkResponse)
                    }

                case "response.output_item.done":
                    if let item = json["item"] as? [String: Any],
                       let itemType = item["type"] as? String {

                        if itemType == "function_call" {
                            response.toolCalls.append(item)
                        }

                        if itemType == "message",
                           let content = item["content"] as? [[String: Any]] {
                            for part in content {
                                if let text = part["text"] as? String {
                                    chunkResponse.content = text
                                    response.content += text
                                    onUpdate(chunkResponse)
                                }
                            }
                        }
                    }

                case "response.completed":
                    if let completedResponse = json["response"] as? [String: Any] {
                        if let id = completedResponse["id"] as? String {
                            response.createdAt = id
                        }
                    }

                case "response.failed":
                    response.error = NSError(
                        domain: "OpenAIProvider",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "\(json)"]
                    )

                default:
                    break
                }
            }
        } catch {
            response.error = error
        }

        return response
    }
    
    func fetchModels() async throws -> [LLMModel] {
        let json = try await ProviderClient.shared.fetchJSON(llmType: .openai)

        guard let data = json["data"] as? [[String: Any]] else { return [] }

        let llmModels = data.compactMap { model -> LLMModel? in
            guard let id = model["id"] as? String else { return nil }
            return LLMModel(id: id, name: id, provider: .openai)
        }
        return llmModels
    }
}

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
        onUpdate: @Sendable @escaping (ProviderResponse) async -> Void
    ) async -> ProviderResponse {
        var response = ProviderResponse(createdAt: "", providerType: .openai, model: model.name, content: "")
        
        var payload: [String: Any] = [
            "model": model.id,
            "input": toOpenAIInput(messages),
            "stream": true
        ]
        
        // REMOVED THINKING FOR NOW, NEED HANDLING/TESTING LATER
        /*
         if (useThinking) {
         payload["reasoning"] = [
         "effort": "medium"
         ]
         }
         */
        
        if !tools.isEmpty {
            payload["tools"] = tools.map { $0.openAISchema() }
            payload["tool_choice"] = "auto"
        }
        
        do {
            try Task.checkCancellation()
            let stream = ProviderClient.shared.streamJSON(
                llmType: .openai,
                payload: payload
            )
            
            for try await jsonData in stream {
                try Task.checkCancellation()
                guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let type = json["type"] as? String else {
                    continue
                }
                
                var chunkResponse = ProviderResponse(createdAt: "", providerType: .openai, model: model.name, content: "")
                
                switch type {
                case "response.output_text.delta":
                    if let delta = json["delta"] as? String {
                        chunkResponse.content = delta
                        response.content += delta
                        await onUpdate(chunkResponse)
                    }
                    
                case "response.output_item.done":
                    if let item = json["item"] as? [String: Any],
                       let itemType = item["type"] as? String,
                       itemType == "function_call" {
                        response.toolCalls.append(item)
                    }
                    
                case "response.completed":
                    if let completedResponse = json["response"] as? [String: Any] {
                        if let id = completedResponse["id"] as? String {
                            response.createdAt = id
                        }
                    }
                    
                case "response.failed":
                    let completedResponse = json["response"] as? [String: Any]
                    let errorInfo = completedResponse?["error"] as? [String: Any]
                    
                    let code = errorInfo?["code"] as? String ?? "unknown_error"
                    let message = errorInfo?["message"] as? String ?? "\(json)"
                    
                    response.error = NSError(
                        domain: "OpenAIProvider",
                        code: -1,
                        userInfo: [
                            NSLocalizedDescriptionKey: "\(code): \(message)"
                        ]
                    )
                    
                default:
                    break
                }
            }
        } catch is CancellationError {
            return ProviderResponse(createdAt: "", providerType: .openai, model: model.name, content: "")
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

extension OpenAIProvider {
    private func toOpenAIInput(_ messages: [Message]) -> [[String: Any]] {
        var result: [[String: Any]] = []

        for message in messages {
            if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                for tc in toolCalls {
                    result.append([
                        "type": "function_call",
                        "call_id": tc.id ?? "",
                        "name": tc.name,
                        "arguments": jsonString(tc.argDict)
                    ])
                }
                continue
            }

            if message.role == MsgSource.tool.name {
                result.append([
                    "type": "function_call_output",
                    "call_id": message.toolCallId ?? "",
                    "output": message.text ?? ""
                ])
                continue
            }

            result.append([
                "role": message.role,
                "content": openAIContent(for: message)
            ])
        }

        return result
    }

    private func openAIContent(for message: Message) -> Any {
        var content: [[String: Any]] = []

        if let text = message.text, !text.isEmpty {
            content.append([
                "type": "input_text",
                "text": text
            ])
        }

        if let attachments = message.attachments {
            for attachment in attachments {
                do {
                    let base64 = try attachment.toBase64()
                    content.append([
                        "type": "input_image",
                        "image_url": "data:\(attachment.mimeType);base64,\(base64)"
                    ])
                } catch {
                    print("Failed to process image attachment: \(error)")
                }
            }
        }

        if content.count == 1,
           let text = content[0]["text"] as? String,
           content[0]["type"] as? String == "input_text" {
            return text
        }

        return content
    }
    
    private func jsonString(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }
}

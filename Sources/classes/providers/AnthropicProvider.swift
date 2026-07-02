//
//  AnthropicProvider.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/7/26.
//

import Foundation

final class AnthropicProvider: LLMProvider {
    func send(
        messages: [Message],
        model: LLMModel,
        tools: [Tool],
        useThinking: Bool,
        contextWindow: Int32,
        onUpdate: @Sendable @escaping (ProviderResponse) async -> Void
    ) async -> ProviderResponse {
        var response = ProviderResponse(createdAt: "", providerType: .anthropic, model: model.name, content: "")

        let systemPrompt = messages
            .filter { $0.role == MsgSource.system.name }
            .compactMap { $0.text }
            .joined(separator: "\n\n")
        
        var payload: [String: Any] = [
            "model": model.id,
            "max_tokens": 8192,
            "messages": toAnthropicMessages(messages),
            "stream": true
        ]
        
        if (!systemPrompt.isEmpty) {
            payload["system"] = systemPrompt
        }
        
        // REMOVED THINKING FOR NOW, NEED HANDLING/TESTING LATER
        /*
        if (useThinking) {
            payload["thinking"] = [
                "type": "enabled",
                "budget_tokens": 2048
            ]
        }
         */

        if !tools.isEmpty {
            payload["tools"] = tools.map { $0.anthropicSchema() }
            payload["tool_choice"] = [
                "type": "auto"
            ]
        }

        do {
            try Task.checkCancellation()
            let stream = ProviderClient.shared.streamJSON(
                llmType: .anthropic,
                payload: payload
            )

            var currentToolCall: [String: Any] = [:]
            var currentToolInput = ""

            for try await jsonData in stream {
                try Task.checkCancellation()
                guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let type = json["type"] as? String else {
                    continue
                }

                var chunkResponse = ProviderResponse(createdAt: "", providerType: .anthropic, model: model.name, content: "")

                switch type {
                case "message_start":
                    if let message = json["message"] as? [String: Any],
                       let id = message["id"] as? String {
                        response.createdAt = id
                    }

                case "content_block_start":
                    if let contentBlock = json["content_block"] as? [String: Any],
                       let blockType = contentBlock["type"] as? String,
                       blockType == "tool_use" {
                        currentToolCall = contentBlock
                        currentToolInput = ""
                    }

                case "content_block_delta":
                    guard let delta = json["delta"] as? [String: Any],
                          let deltaType = delta["type"] as? String else {
                        continue
                    }

                    if (deltaType == "text_delta"),
                       let text = delta["text"] as? String {
                        chunkResponse.content = text
                        response.content += text
                        await onUpdate(chunkResponse)
                    } else if (deltaType == "input_json_delta"),
                              let jsonDelta = delta["partial_json"] as? String {
                        currentToolInput += jsonDelta
                    }
                    
                case "content_block_stop":
                    if !currentToolCall.isEmpty {
                        currentToolCall["input_json"] = currentToolInput

                        if let inputData = currentToolInput.data(using: .utf8),
                           let input = try? JSONSerialization.jsonObject(with: inputData) as? [String: Any] {
                            currentToolCall["input"] = input
                        }

                        response.toolCalls.append(currentToolCall)
                        currentToolCall = [:]
                        currentToolInput = ""
                    }
                    
                case "message_delta":
                    if let delta = json["delta"] as? [String: Any],
                       let stopReason = delta["stop_reason"] as? String {
                        if stopReason == "stop_sequence" || stopReason == "end_turn" {
                            // Message complete
                        }
                    }
                    
                case "message_stop":
                    break

                case "error":
                    response.error = NSError(
                        domain: "AnthropicProvider",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "\(json)"]
                    )

                default:
                    break
                }
            }
        } catch is CancellationError {
            return ProviderResponse(createdAt: "", providerType: .anthropic, model: model.name, content: "")
        } catch {
            response.error = error
        }

        return response
    }
    
    func fetchModels() async throws -> [LLMModel] {
        let json = try await ProviderClient.shared.fetchJSON(llmType: .anthropic)

        guard let data = json["data"] as? [[String: Any]] else { return [] }

        let llmModels = data.compactMap { model -> LLMModel? in
            guard let id = model["id"] as? String else { return nil }
            let name = model["display_name"] as? String ?? id
            
            return LLMModel(id: id, name: name, provider: .anthropic)
        }
        return llmModels
    }
}

extension AnthropicProvider {
    private func toAnthropicMessages(_ messages: [Message]) -> [[String: Any]] {
        var result: [[String: Any]] = []

        for message in messages {
            if message.role == MsgSource.system.name {
                continue
            }

            if let toolCalls = message.toolCalls,
               !toolCalls.isEmpty {
                result.append([
                    "role": MsgSource.assistant.name,
                    "content": toolCalls.map { tc in
                        [
                            "type": "tool_use",
                            "id": tc.id ?? "",
                            "name": tc.name,
                            "input": tc.argDict
                        ]
                    }
                ])
                continue
            }

            if message.role == MsgSource.tool.name {
                result.append([
                    "role": MsgSource.user.name,
                    "content": [
                        [
                            "type": "tool_result",
                            "tool_use_id": message.toolCallId ?? message.uuid,
                            "content": message.text ?? ""
                        ]
                    ]
                ])
                continue
            }

            var contentArray: [[String: Any]] = []

            if let text = message.text,
               !text.isEmpty {
                contentArray.append([
                    "type": "text",
                    "text": text
                ])
            }

            if let attachments = message.attachments,
               !attachments.isEmpty {
                for attachment in attachments {
                    do {
                        let base64 = try attachment.toBase64()
                        contentArray.append([
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": attachment.mimeType,
                                "data": base64
                            ]
                        ])
                    } catch {
                        print("Failed to process image attachment: \(error)")
                    }
                }
            }

            result.append([
                "role": message.role == MsgSource.assistant.name ? MsgSource.assistant.name : MsgSource.user.name,
                "content": contentArray.isEmpty ? "" : contentArray
            ])
        }

        return result
    }
}

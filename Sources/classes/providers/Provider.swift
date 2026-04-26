import Foundation
import AnyCodable

struct ProviderResponse {
    var createdAt: String
    var model: String
    var content: String
    var thinking: String = ""
    var toolCalls: [[String: Any]] = []
    var totalElapsedSec: Int = 0
    var error: Error? = nil
}

protocol LLMProvider {
    func send(
        messages: [Message],
        model: String,
        tools: [Tool],
        useThinking: Bool,
        onUpdate: @escaping (ProviderResponse) -> Void
    ) async -> ProviderResponse
}

class Provider {
    static func provider(for type: LLMClient.LLMType) -> LLMProvider {
        switch type {
        case .ollama:
            return OllamaProvider()
        }
    }
}

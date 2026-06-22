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

struct LLMModel: Codable, Identifiable {
    var id: String
    var name: String
    var provider: ProviderClient.ProviderType
}

protocol LLMProvider {
    func fetchModels() async throws -> [LLMModel]
    
    func send(
        messages: [Message],
        model: LLMModel,
        tools: [Tool],
        useThinking: Bool,
        contextWindow: Int32,
        onUpdate: @escaping (ProviderResponse) -> Void
    ) async -> ProviderResponse
}

class Provider: Codable {
    let type: ProviderClient.ProviderType
    let apiKey: String
    let models: [LLMModel]
    let updatedTimestamp: Int64
    
    init(type: ProviderClient.ProviderType, apiKey: String, models: [LLMModel], updatedTimestamp: Int64 = Date.now.epochMillis) {
        self.type = type
        self.apiKey = apiKey
        self.models = models
        self.updatedTimestamp = updatedTimestamp
    }
    
    static func getProviders() async -> [Provider] {
        var providers: [Provider] = []
        for type in ProviderClient.ProviderType.allCases {
            let models = try? await fetchModels(for: type)
            providers.append(Provider(type: type, apiKey: (type.apiKey ?? ""), models: (models ?? [])))
        }
        return providers
    }
    
    static func getProvider(_ type: ProviderClient.ProviderType) async -> Provider {
        let models = try? await fetchModels(for: type)
        return Provider(type: type, apiKey: (type.apiKey ?? ""), models: (models ?? []))
    }
    
    static func provider(for type: ProviderClient.ProviderType) -> LLMProvider {
        switch type {
        case .ollama:
            return OllamaProvider()
        case .openai:
            return OpenAIProvider()
        case .anthropic:
            return AnthropicProvider()
        }
    }
    
    static func fetchModels(for type: ProviderClient.ProviderType) async throws -> [LLMModel] {
        let provider = Provider.provider(for: type)
        return try await provider.fetchModels()
    }
}

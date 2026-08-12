//
//  Provider.swift
//  DAWSON
//
//  Created by Ethan Brown on 3/19/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import AnyCodable

class Provider: Codable {
    let type: ProviderClient.ProviderType
    var apiKey: String
    var useOAuth: Bool
    var availableModels: [LLMModel]
    var preferredModelIDs: [String]
    var defaultModelID: String
    var updatedTimestamp: Int64
    
    static let providersDirectory = DAWSON.databank.appendingPathComponent("providers")
    static let providersMetadataDirectory = providersDirectory.appendingPathComponent("metadata")
    
    var defaultModel: LLMModel? {
        availableModels.first(where: { $0.id == defaultModelID }) ?? availableModels.first
    }
    
    var preferredModels: [LLMModel] {
        availableModels.filter { preferredModelIDs.contains($0.id) }
    }
    
    init(type: ProviderClient.ProviderType,
         apiKey: String = "",
         useOAuth: Bool = false,
         availableModels: [LLMModel] = [],
         preferredModelIDs: [String] = [],
         defaultModelID: String = "",
         updatedTimestamp: Int64 = Date.now.epochMillis
    ) {
        self.type = type
        self.apiKey = apiKey
        self.availableModels = availableModels
        self.preferredModelIDs = preferredModelIDs
        self.defaultModelID = defaultModelID
        self.useOAuth = useOAuth
        self.updatedTimestamp = updatedTimestamp
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
}

extension Provider {
    
    static func loadAllProviders() -> [Provider] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: providersMetadataDirectory, includingPropertiesForKeys: nil) else { return [] }

        var providers: [Provider] = []
        for fileURL in files {
            guard fileURL.pathExtension == "json",
                  let data = try? Data(contentsOf: fileURL),
                  let provider = try? JSONDecoder().decode(Provider.self, from: data) else { continue }

            providers.append(provider)
        }

        return providers
    }
    
    static func loadProvider(providerName: String) -> Provider? {
        let url = metadataURL(providerName: providerName)
        guard let data = try? Data(contentsOf: url),
              let provider = try? JSONDecoder().decode(Provider.self, from: data) else { return nil }
        
        return provider
    }
    
    func saveMetadata() {
        do {
            try FileManager.default.createDirectory(at: Provider.providersMetadataDirectory, withIntermediateDirectories: true)

            let data = try JSONEncoder().encode(self)
            try data.write(to: Provider.metadataURL(providerName: type.rawValue), options: .atomic)
            print("Successfully saved Provider \(type.rawValue) metadata")
        } catch {
            print("Failed to save Provider \(type.rawValue) metadata: ", error)
        }
    }
    
    private static func metadataURL(providerName: String) -> URL {
        return Provider.providersMetadataDirectory.appendingPathComponent("\(providerName).json")
    }
}

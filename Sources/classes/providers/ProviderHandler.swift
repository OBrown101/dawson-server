//
//  ProviderHandler.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/25/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

class ProviderHandler: @unchecked Sendable {
    static let shared = ProviderHandler()
    
    private var activeProviders: [ProviderClient.ProviderType: Provider] = [:]
    
    init() {
        var savedProviders = Provider.loadAllProviders()
        if (savedProviders.isEmpty) {
            savedProviders = ProviderClient.ProviderType.allCases.map { Provider(type: $0) }
            savedProviders.forEach { $0.saveMetadata() }
        }
        
        activeProviders = Dictionary(uniqueKeysWithValues: savedProviders.map { ($0.type, $0) })
        print("Loaded Providers: \(savedProviders)")
        
        activeProviders.forEach { (type, provider) in
            loginOAuth(type, login: provider.useOAuth)
        }
        
        startModelFetcher()
    }
    
    func startModelFetcher() {
        Task {
            while true {
                for (type, provider) in activeProviders {
                    await fetchAvailableModels(for: type, useOAuth: provider.useOAuth)
                }
                try await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
    }
    
    func loginOAuth(_ type: ProviderClient.ProviderType, login: Bool = true) {
        // Currently only OpenAI is configured to handle OAuth
        guard (type.supportsOAuth) else { return }
        
        Task {
            if (login) {
                try await OpenAIOAuth.shared.login()
            } else {
                OpenAIOAuth.shared.logout()
            }
        }
    }
    
    func updateProvider(provider: Provider) {
        // NOTE: provider.models not updated here, already updated automatically
        let curUseOAuth = activeProviders[provider.type]?.useOAuth
        activeProviders[provider.type]?.apiKey = provider.apiKey
        activeProviders[provider.type]?.useOAuth = provider.useOAuth
        activeProviders[provider.type]?.preferredModelIDs = provider.preferredModelIDs
        activeProviders[provider.type]?.defaultModelID = provider.defaultModelID
        activeProviders[provider.type]?.updatedTimestamp = Date.now.epochMillis
        activeProviders[provider.type]?.saveMetadata()
        
        if (curUseOAuth != provider.useOAuth) {
            loginOAuth(provider.type, login: provider.useOAuth)
        }
        
        if let updatedProvider = activeProviders[provider.type] {
            DAWSON.shared.broadcastProviderUpsert(updatedProvider)
        }
    }
    
    func getProviders() -> [Provider] {
        return activeProviders.values.map { $0 }
    }
    
    func getProvider(_ type: ProviderClient.ProviderType) -> Provider? {
        return activeProviders[type]
    }
    
    func getModelFromName(_ name: String) -> LLMModel? {
        let models = activeProviders.values.flatMap({ $0.availableModels })
        return models.first(where: { $0.name == name })
    }
    
    func getAPIKey(_ type: ProviderClient.ProviderType) -> String? {
        return activeProviders[type]?.apiKey
    }
    
    func setAPIKey(_ type: ProviderClient.ProviderType, key: String) {
        activeProviders[type]?.apiKey = key
    }
    
    private func fetchAvailableModels(for type: ProviderClient.ProviderType, useOAuth: Bool) async {
        let models = try? await type.fetchModels(useOAuth: useOAuth)
        
        activeProviders[type]?.availableModels = models ?? []
        activeProviders[type]?.updatedTimestamp = Date.now.epochMillis
    }
}

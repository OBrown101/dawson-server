//
//  ServerSettings.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/7/26.
//

import Foundation

class ServerSettings: @unchecked Sendable {
    static let shared = ServerSettings()

    private let UserDefault_IsFirstLaunch = "UserDefault_IsFirstLaunch"
    var isFirstLaunch: Bool {
        get {
            let value = UserDefaults.standard.bool(forKey: UserDefault_IsFirstLaunch)
            if !value {
                // Init values
                UserDefaults.standard.set(true, forKey: UserDefault_IsFirstLaunch)
            }

            return value
        }
    }
    
    private let UserDefault_ProviderAPIKeys = "UserDefault_ProviderAPIKeys"
    var providerAPIKeys: [ProviderClient.ProviderType: String] {
        get {
            let saved = UserDefaults.standard.dictionary(forKey: UserDefault_ProviderAPIKeys) as? [String: String] ?? [:]

            return Dictionary(uniqueKeysWithValues: saved.compactMap { key, value in
                guard let type = ProviderClient.ProviderType(rawValue: key) else { return nil }
                return (type, value)
            })
        }
        set {
            let raw = Dictionary(uniqueKeysWithValues: newValue.map {
                ($0.key.rawValue, $0.value)
            })

            UserDefaults.standard.set(raw, forKey: UserDefault_ProviderAPIKeys)
        }
    }
    
    private let UserDefault_DawsonLLMModel = "UserDefault_DawsonLLMModel"
    var dawsonLLMModel: String? {
        get {
            return UserDefaults.standard.string(forKey: UserDefault_DawsonLLMModel)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefault_DawsonLLMModel)
        }
    }
    
    private let UserDefault_SquirebotLLMModel = "UserDefault_SquirebotLLMModel"
    var squirebotLLMModel: String? {
        get {
            return UserDefaults.standard.string(forKey: UserDefault_SquirebotLLMModel)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefault_SquirebotLLMModel)
        }
    }
    
    private let UserDefault_PageLLMModel = "UserDefault_PageLLMModel"
    var pageLLMModel: String? {
        get {
            return UserDefaults.standard.string(forKey: UserDefault_PageLLMModel)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefault_PageLLMModel)
        }
    }
}


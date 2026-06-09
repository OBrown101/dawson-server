//
//  ServerSettings.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/7/26.
//

import Foundation

class ServerSettings: @unchecked Sendable {
    static let shared = ServerSettings()

    let UserDefault_IsFirstLaunch = "UserDefault_IsFirstLaunch"
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
}


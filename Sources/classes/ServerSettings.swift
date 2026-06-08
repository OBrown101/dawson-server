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
    var providerAPIKeys: [ProviderClient.ProviderType: String]? {
        get {
            return UserDefaults.standard.dictionary(forKey: UserDefault_ProviderAPIKeys) as? [ProviderClient.ProviderType: String]
        }
        set {
            if let newValue = newValue {
                UserDefaults.standard.set(newValue, forKey: UserDefault_ProviderAPIKeys)
            } else {
                UserDefaults.standard.removeObject(forKey: UserDefault_ProviderAPIKeys)
            }
        }
    }
}


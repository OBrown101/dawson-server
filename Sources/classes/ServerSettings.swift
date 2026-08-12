//
//  ServerSettings.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/7/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
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


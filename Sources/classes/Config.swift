//
//  Config.swift
//  
//
//  Created by Ethan Brown on 3/31/26.
//

import Foundation

enum ConfigKey: String, CaseIterable {
    case enabledTools
    case speakResponses
    case useThinking
    case maxMessages
    case userMessageTerm
}

class Config: @unchecked Sendable {
    static let shared = Config()

    private let configPath: String
    private var settings: [ConfigKey: Any] = [:]

    private init() {
        // Path to config.json
        let workspace = ("~/DAWSON/workspace/config" as NSString).expandingTildeInPath
        configPath = "\(workspace)/config.json"

        load()
    }

    // Load Config
    func load() {
        let fileURL = URL(fileURLWithPath: configPath)
        guard let data = try? Data(contentsOf: fileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // No file or failed to parse, keep defaults
            print("Config: Could not load JSON, using defaults.")
            return
        }

        // Map JSON to enum keys
        for key in ConfigKey.allCases {
            if let value = json[key.rawValue] {
                settings[key] = value
            }
        }
    }

    // Save Config
    func save() {
        var json: [String: Any] = [:]
        for (key, value) in settings {
            json[key.rawValue] = value
        }

        let fileURL = URL(fileURLWithPath: configPath)
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            try data.write(to: fileURL)
        } catch {
            print("Config: Failed to save JSON - \(error.localizedDescription)")
        }
    }

    // Get / Set
    func getConfig<T>(_ key: ConfigKey) -> T? {
        return settings[key] as? T
    }

    func setConfig(_ key: ConfigKey, value: Any) {
        settings[key] = value
        save()
    }
}

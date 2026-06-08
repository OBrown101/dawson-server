//
//  File.swift
//  
//
//  Created by Ethan Brown on 3/31/26.
//

import Foundation

class SelfConfig: Tool {
    let name = "self_config"
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": name,
            "description": "Reads or updates DAWSON's config file (not related to personality). Used to enable/disable tools, enable/disable speaking, enable/disable thinking, etc.",
            "parameters": [
                "type": "object",
                "properties": [
                    "read": [
                        "type": "boolean",
                        "description": "Set true to read the current config"
                    ],
                    "updates": [
                        "type": "object",
                        "description": "Dictionary of keys to update in the config",
                        "additionalProperties": true
                    ]
                ],
                "required": []
            ]
        ]
    }
    
    func anthropicSchema() -> [String : Any] {
        return [
            "name": name,
            "description": "Reads or updates DAWSON's config file (not related to personality). Used to enable/disable tools, enable/disable speaking, enable/disable thinking, etc.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "read": [
                        "type": "boolean",
                        "description": "Set true to read the current config"
                    ],
                    "updates": [
                        "type": "object",
                        "description": "Dictionary of keys to update in the config",
                        "additionalProperties": true
                    ]
                ],
                "required": []
            ]
        ]
    }
    
    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Reads or updates DAWSON's config file (not related to personality). Used to enable/disable tools, enable/disable speaking, enable/disable thinking, etc.",
                "parameters": [
                    "type": "object",
                    "required": [],
                    "properties": [
                        "read": [
                            "type": "boolean",
                            "description": "Set true to read the current config"
                        ],
                        "updates": [
                            "type": "object",
                            "description": "Dictionary of keys to update in the config"
                        ]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        let url = URL(fileURLWithPath: DAWSON.root.path + "/workspace/config.json")

        var currentConfig: [String: Any] = [:]
        if let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            currentConfig = json
        }

        if let read = args["read"] as? Bool, read {
            if let jsonData = try? JSONSerialization.data(withJSONObject: currentConfig, options: .prettyPrinted),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                return jsonStr
            }
            return "Error: Could not read config."
        }

        // Apply updates
        if let updates = args["updates"] as? [String: Any] {
            for (key, value) in updates {
                currentConfig[key] = value
            }
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: currentConfig, options: .prettyPrinted)
                try jsonData.write(to: url)
                return "Config updated successfully."
            } catch {
                return "Error updating config: \(error.localizedDescription)"
            }
        }

        return "No action performed."
    }
}

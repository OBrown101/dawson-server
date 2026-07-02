//
//  SpawnAgent.swift
//  DAWSON
//
//  Created by Squirebot.
//

import Foundation

/*
class SpawnAgent: PermissionAware {
    let name = "spawn_agent"
    let description = "Spawns a new sub-agent with specified configuration. Creates an agent and its associated chat session."

    func permissionRequests(args: [String : Any]) -> [PermissionRequest] {
        return [
            PermissionRequest(action: .write, target: "agents")
        ]
    }

    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": name,
            "description": description,
            "parameters": [
                "type": "object",
                "required": ["type", "model"],
                "properties": [
                    "type": [
                        "type": "string",
                        "description": "Agent type: 'squireBot' or 'dawson'"
                    ],
                    "model": [
                        "type": "string",
                        "description": "LLM model identifier to use for the agent"
                    ],
                    "mode": [
                        "type": "string",
                        "description": "Mode type: 'egg', 'assistant', or other valid mode",
                        "default": "egg"
                    ],
                    "name": [
                        "type": "string",
                        "description": "Optional name/description for the agent",
                        "default": ""
                    ]
                ]
            ]
        ]
    }

    func anthropicSchema() -> [String : Any] {
        return [
            "name": name,
            "description": description,
            "input_schema": [
                "type": "object",
                "required": ["type", "model"],
                "properties": [
                    "type": [
                        "type": "string",
                        "description": "Agent type: 'squireBot' or 'dawson'"
                    ],
                    "model": [
                        "type": "string",
                        "description": "LLM model identifier to use for the agent"
                    ],
                    "mode": [
                        "type": "string",
                        "description": "Mode type: 'egg', 'assistant', or other valid mode",
                        "default": "egg"
                    ],
                    "name": [
                        "type": "string",
                        "description": "Optional name/description for the agent",
                        "default": ""
                    ]
                ]
            ]
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "required": ["type", "model"],
                    "properties": [
                        "type": [
                            "type": "string",
                            "description": "Agent type: 'squireBot' or 'dawson'"
                        ],
                        "model": [
                            "type": "string",
                            "description": "LLM model identifier to use for the agent"
                        ],
                        "mode": [
                            "type": "string",
                            "description": "Mode type: 'egg', 'assistant', or other valid mode",
                            "default": "egg"
                        ],
                        "name": [
                            "type": "string",
                            "description": "Optional name/description for the agent",
                            "default": ""
                        ]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String : Any]) async -> String {
        guard let typeStr = args["type"] as? String, !typeStr.isEmpty else {
            return "Error: 'type' parameter is required and must be a string."
        }

        guard let modelStr = args["model"] as? String, !modelStr.isEmpty else {
            return "Error: 'model' parameter is required and must be a string."
        }

        // Parse agent type
        let agentType: Agent.AgentType
        switch typeStr.lowercased() {
        case "squirebot", "squire_bot", "squire":
            agentType = .squireBot
        case "dawson":
            agentType = .dawson
        default:
            return "Error: Invalid agent type '\(typeStr)'. Valid types: 'squireBot', 'dawson'."
        }

        // Parse mode (optional, defaults to egg)
        let modeStr = args["mode"] as? String ?? ModeType.egg.rawValue
        let mode = ModeType.fromName(modeStr)

        // Get or create a UUID for the new agent
        let agentUUID = UUID().uuidString
        let chatUUID = UUID().uuidString

        // Find available models and select one matching the requested model name
        let allModels = await Provider.getProviders().flatMap({ $0.models })

        let selectedModel: LLMModel
        if let matchingModel = allModels.first(where: { $0.name == modelStr || $0.model == modelStr }) {
            selectedModel = matchingModel
        } else if let firstModel = allModels.first {
            // Fallback to first available model if requested not found
            print("Warning: Model '\(modelStr)' not found, using '\(firstModel.name ?? firstModel.model)'.")
            selectedModel = firstModel
        } else {
            return "Error: No models available from any provider."
        }

        // Spawn the agent via AgentHandler
        AgentHandler.shared.spawnAgent(
            uuid: agentUUID,
            userUUID: "",  // Will be set by chat creation
            type: agentType,
            mode: mode,
            model: selectedModel
        )

        // Create a new chat for this spawned agent
        let newChat = Chat(uuid: chatUUID, userUUID: "", agentUUID: agentUUID)
        DAWSON.shared.upsertChat(newChat)

        return "Agent spawned successfully.\n" +
               "  Agent UUID: \(agentUUID)\n" +
               "  Chat UUID: \(chatUUID)\n" +
               "  Type: \(agentType.rawValue ?? typeStr)\n" +
               "  Model: \(selectedModel.name ?? selectedModel.model ?? "unknown")\n" +
               "  Mode: \(modeStr)"
    }
}
*/

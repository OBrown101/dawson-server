//
//  UpdateAgent.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/2/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

class UpdateAgent: ChatAware {
    static let name = "update_agent"

    private var chat: Chat?

    func setChat(_ chat: Chat?) {
        self.chat = chat
    }

    func permissionRequests(args: [String: Any]) -> [PermissionRequest] {
        return [
            PermissionRequest(action: .delegate)
        ]
    }

    private let toolDescription = """
        Updates the NON-TRUST settings of a Squirebot: name, model, \
        thought window, context window, and whether it uses thinking. Works \
        on your own workers and on the user's Squirebots. This tool cannot \
        change anything trust-bearing — mode, workspace, and ownership are \
        changed only by the user (or, for ownership, via \(ReleaseWorker.name) \
        with the user's approval). The target must not be mid-run. Use \
        \(ListAgents.name) to find agent UUIDs and current settings.
        """

    private let parameterSchema: [String: Any] = [
        "type": "object",
        "required": ["agent_uuid"],
        "properties": [
            "agent_uuid": [
                "type": "string",
                "description": "UUID of the Squirebot agent (from \(ListAgents.name))"
            ],
            "name": [
                "type": "string",
                "description": "New agent name. Omit to leave unchanged."
            ],
            "model": [
                "type": "string",
                "description": "New LLM model by name. Omit to leave unchanged."
            ],
            "thought_window": [
                "type": "integer",
                "description": "Max reasoning iterations per run. Omit to leave unchanged."
            ],
            "context_window": [
                "type": "integer",
                "description": "Context window size in tokens. Omit to leave unchanged."
            ],
            "use_thinking": [
                "type": "boolean",
                "description": "Whether the agent uses extended thinking. Omit to leave unchanged."
            ]
        ]
    ]

    func openAISchema() -> [String: Any] {
        return [
            "type": "function",
            "name": UpdateAgent.name,
            "description": toolDescription,
            "parameters": parameterSchema
        ]
    }

    func anthropicSchema() -> [String: Any] {
        return [
            "name": UpdateAgent.name,
            "description": toolDescription,
            "input_schema": parameterSchema
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": UpdateAgent.name,
                "description": toolDescription,
                "parameters": parameterSchema
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let parentChat = chat,
              let parent = AgentHandler.shared.getAgent(parentChat.agentUUID) else {
            return "Error: No originating chat context."
        }

        guard let agentUUID = args["agent_uuid"] as? String, !agentUUID.isEmpty else {
            return "Error: Missing required parameter 'agent_uuid'."
        }

        guard let target = AgentHandler.shared.getAgent(agentUUID) else {
            return "Error: No agent found with UUID '\(agentUUID)'. Use \(ListAgents.name) to see existing agents."
        }
        guard (target.userUUID == parentChat.userUUID) else {
            return "Error: That agent belongs to a different user."
        }
        guard (target.type == .squireBot) else {
            return "Error: \(UpdateAgent.name) can only update Squirebots."
        }
        if let otherParent = target.parentAgentUUID, (otherParent != parent.uuid) {
            return "Error: That Squirebot is operated by another agent (\(otherParent)) and cannot be updated."
        }

        // Settings like model and context window must not change under a live run.
        if (await AgentRunRegistry.shared.isAgentRunning(agentUUID: target.uuid)) {
            return "Error: That agent is currently mid-run. Wait for it to finish (or cancel it) before updating its settings."
        }

        var changes: [String] = []

        if let newName = (args["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           (!newName.isEmpty) {
            target.name = newName
            changes.append("name -> '\(newName)'")
        }

        if let modelName = args["model"] as? String,
           (!modelName.isEmpty) {
            guard let newModel = ProviderHandler.shared.getModelFromName(modelName) else {
                return "Error: Unknown model '\(modelName)'. No changes were applied."
            }
            target.setModel(newModel)
            changes.append("model -> \(newModel.name)")
        }

        if let thoughtWindow = args["thought_window"] as? Int {
            guard (thoughtWindow > 0) else {
                return "Error: 'thought_window' must be a positive integer. No changes were applied."
            }
            target.thoughtWindow = thoughtWindow
            changes.append("thoughtWindow -> \(thoughtWindow)")
        }

        if let contextWindow = args["context_window"] as? Int {
            guard (contextWindow >= 1024) else {
                return "Error: 'context_window' must be at least 1024. No changes were applied."
            }
            target.contextWindow = Int32(contextWindow)
            changes.append("contextWindow -> \(contextWindow)")
        }

        if let useThinking = args["use_thinking"] as? Bool {
            target.useThinking = useThinking
            changes.append("useThinking -> \(useThinking)")
        }

        guard (!changes.isEmpty) else {
            return "Error: Provide at least one setting to change (name, model, thought_window, context_window, use_thinking)."
        }

        target.updatedTimestamp = Date.now.epochMillis
        target.saveMetadata()
        DAWSON.shared.broadcastAgentUpsert(target)

        return "Updated agent '\(target.name)' (\(agentUUID)): \(changes.joined(separator: ", "))."
    }
}

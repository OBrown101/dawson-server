//
//  ListAgents.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/28/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

class ListAgents: ChatAware {
    static let name = "list_agents"

    private var chat: Chat?

    func setChat(_ chat: Chat?) {
        self.chat = chat
    }

    private let toolDescription = """
        Lists all of the user's agents: ownership (your worker vs. the user's \
        own chat), permission mode (including the effective mode when clamped \
        to yours), model, state, workspace, and each chat's UUID and topic. \
        Use before delegating — an existing agent with relevant context may \
        beat a fresh one — and to predict whether messaging a user-owned chat \
        will require the user's approval (it does when the target outranks \
        you). Takes no parameters.
        """

    private let parameterSchema: [String: Any] = [
        "type": "object",
        "properties": [:] as [String: Any]
    ]

    func openAISchema() -> [String: Any] {
        return [
            "type": "function",
            "name": ListAgents.name,
            "description": toolDescription,
            "parameters": parameterSchema
        ]
    }

    func anthropicSchema() -> [String: Any] {
        return [
            "name": ListAgents.name,
            "description": toolDescription,
            "input_schema": parameterSchema
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": ListAgents.name,
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

        let agents = AgentHandler.shared.getAgents(userUUID: parentChat.userUUID)
        guard (!agents.isEmpty) else {
            return "No agents exist for this user yet."
        }

        let lines = agents.map { agent -> String in
            let agentChat = DAWSON.shared.getChatForAgent(agent.uuid)
            let topic = agentChat.map { chat -> String in
                let subtitle = (chat.subtitle.isEmpty) ? chat.title : chat.subtitle
                return (subtitle.isEmpty) ? "(no topic yet)" : subtitle
            } ?? "(no chat)"
            
            let createdTimestamp = if let created = agentChat?.createdTimestamp {
                String(created)
            } else {
                "-"
            }
            
            let ownership: String
            if (agent.uuid == parent.uuid) {
                ownership = "you"
            } else if (agent.parentAgentUUID == parent.uuid) {
                ownership = "your worker"
            } else if (agent.parentAgentUUID != nil) {
                ownership = "another agent's worker"
            } else {
                ownership = "user's chat"
            }

            let effective = agent.effectiveMode
            let modeText = (effective == agent.mode) ? "\(agent.mode)" : "\(agent.mode) (effective: \(effective), clamped to yours)"

            let approvalNote = ((agent.parentAgentUUID == nil)
                                && (agent.uuid != parent.uuid)
                                && (effective.rank > parent.effectiveMode.rank))
                ? " — messaging requires user approval (outranks you)"
                : ""
            
            let lastMsgTimestamp = if let timestamp = agentChat?.messages.compactMap({ $0.timestamp }).max() {
                String(timestamp)
            } else {
                ""
            }
            
            return """
            • \(agent.type.name) [\(ownership)] [\(agent.state)] [\(agent.uuid)] [birth: \(agent.createdTimestamp)(epoch-millis)]\(approvalNote)
              Chat UUID: \(agentChat?.uuid ?? "-") [created: \(createdTimestamp)(epoch-millis)]
              Topic: \(topic)
              Mode: \(modeText) | Model: \(agent.model.name)
              Workspace: \(agent.effectiveDirectories.isEmpty ? "(none)" : agent.effectiveDirectories.joined(separator: ", "))
              Last message timestamp: \(lastMsgTimestamp)(epoch-millis)
            """
        }

        return """
        The kingdom's agents (\(agents.count)):

        \(lines.joined(separator: "\n\n"))
        """
    }
}

//
//  GetSessionInfo.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/20/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

class GetSessionInfo: ChatAware {
    static let name = "get_session_info"
    
    var chat: Chat? = nil
    func setChat(_ chat: Chat?) {
        self.chat = chat
    }
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": GetSessionInfo.name,
            "description": """
            Gets details about the current chat-session with the user, including the user UUID, mode, and the permissions that are enabled for that mode.
            """,
            "parameters": [
                "type": "object",
                "properties": [:],
                "required": []
            ]
        ]
    }
    func anthropicSchema() -> [String : Any] {
        return [
            "name": GetSessionInfo.name,
            "description": """
            Gets details about the current chat-session with the user, including the user UUID, mode, and the permissions that are enabled for that mode.
            """,
            "input_schema": [
                "type": "object",
                "properties": [:],
                "required": []
            ]
        ]
    }
    
    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": GetSessionInfo.name,
                "description": """
                Gets details about the current chat‑session with the user, including the user UUID, mode, and the
                permissions that are enabled for that mode.
                """,
                "parameters": [
                    "type": "object",
                    "properties": [:]
                ]
            ]
        ]
    }

    func execute(args: [String : Any]) async -> String {
        return getInfo()
    }
    
    func getInfo() -> String {
        guard let chat = chat else { return "Unable to find current chat session." }
        guard let agent = AgentHandler.shared.getAgent(chat.agentUUID) else { return "Unable to find agent assigned to chat session." }
        
        let mode = agent.effectiveMode
        let modeNote = (mode == agent.mode) ? "" : " (clamped from \(agent.mode.rawValue) to stay within your orchestrator's mode)"

        let workspace = (agent.effectiveDirectories.isEmpty)
            ? "None configured"
            : "\n" + agent.effectiveDirectories.map { "        - \($0)" }.joined(separator: "\n")
        
        var limitString = "No limit"
        if let limit = agent.mode.iterationLimit {
            limitString = String(limit)
        }
        
        let now = Date()
        let timeFormatter = DateFormatter()
        let dateFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .medium
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy"
        
        return """
        ## Current Chat Session Information ##
        Current Time: \(timeFormatter.string(from: now))
        Current Date: \(dateFormatter.string(from: now))
        User UUID: \(chat.userUUID)
        Mode: \(mode.rawValue)\(modeNote)
        Model: \(agent.model.name)
        Model Provider: \(agent.model.provider.rawValue)
        Workspace directories: \(workspace)
        Permissions:
            Reading files: \(mode.permissionDescription(for: .read))
            Writing files: \(mode.permissionDescription(for: .write))
            Running read-only commands: \(mode.permissionDescription(for: .read))
            Running write/modify commands: \(mode.permissionDescription(for: .write))
            Web access: \(mode.permissionDescription(for: .web))
            Installing packages: \(mode.permissionDescription(for: .install))
            Delegating to agents: \(mode.permissionDescription(for: .delegate))
            Modifying the shared harness: \(mode.permissionDescription(for: .harness))
        Iteration limit (for main agent-loop): \(limitString)
        """
    }
}

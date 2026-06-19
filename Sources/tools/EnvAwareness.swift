//
//  EnvAwareness.swift
//
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation

class EnvAwareness: PermissionAware {
    let name = "environmental_awareness"
    
    func permissionRequests(args: [String : Any]) -> [PermissionRequest] {
        return [
            PermissionRequest(action: .read)
        ]
    }
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": name,
            "description": "Provides agent with current environmental awareness data such as time/date, timezone, operating system, DAWSON project root directory, etc.",
            "parameters": [
                "type": "object",
                "properties": [:],
                "required": []
            ]
        ]
    }
    func anthropicSchema() -> [String : Any] {
        return [
            "name": name,
            "description": "Provides agent with current environmental awareness data such as time/date, timezone, operating system, DAWSON project root directory, etc.",
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
                "name": name,
                "description": "Provides agent with current environmental awareness data such as time/date, timezone, operating system, DAWSON project root and directory, etc.",
                "parameters": [
                    "type": "object",
                    "required": [],
                    "properties": [:]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        formatter.timeZone = TimeZone.current
        
        let dateString = formatter.string(from: now)
        let timezoneName = TimeZone.current.identifier
        let user = NSUserName()

        let info = """
        Date & time: \(dateString)
        Time zone: \(timezoneName)
        DAWSON program root directory: \(DAWSON.root)
        DAWSON program chat metadata: \(Chat.chatsMetadataDirectory)
        DAWSON program chat conversation messages: \(Chat.chatsMessagesDirectory)
        DAWSON program agent metadata: \(Agent.agentsMetadataDirectory)
        DAWSON program agent conversation history: \(Agent.agentsHistoryDirectory)
        """

        return info
    }
}

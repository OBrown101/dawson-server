//
//  GetSessionInfo.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/20/26.
//

class GetSessionInfo: ChatAware {
    let name = "get_session_info"
    
    var chat: Chat? = nil
    func setChat(_ chat: Chat?) {
        self.chat = chat
    }
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": name,
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
            "name": name,
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
                "name": name,
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
        
        var limitString = "No limit"
        if let limit = agent.mode.iterationLimit {
            limitString = String(limit)
        }
        
        return """
        ## Current Chat Session Information ##
        User UUID: \(chat.userUUID)
        Mode: \(agent.mode.rawValue)
        Permissions:
            canRead: \(agent.mode.permissionDescription(for: .read))
            canWrite: \(agent.mode.permissionDescription(for: .write))
            canCommands: \(agent.mode.permissionDescription(for: .command))
            canSudo: \(agent.mode.permissionDescription(for: .sudo))
            iteration limit (for main agent-loop): \(limitString)
        """
    }
}

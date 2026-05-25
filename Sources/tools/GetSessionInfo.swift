//
//  GetSessionInfo.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/20/26.
//

class GetSessionInfo: ChatSessionAware {
    let name = "get_session_info"
    private var session: ChatSessionInfo?

    func setSession(_ session: ChatSessionInfo) {
        self.session = session
    }

    func schema() -> [String: Any] {
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
        guard let session = session else {
            return "Error: No session set for the tool."
        }

        var limitString = "No limit"
        if let limit = session.mode.iterationLimit {
            limitString = String(limit)
        }
        
        return """
        ## Current Chat Session Information ##
        User UUID: \(session.userUUID)
        Mode: \(session.mode.rawValue)
        Permissions:
            canRead: \(session.mode.permissionDescription(for: .read))
            canWrite: \(session.mode.permissionDescription(for: .write))
            canCommands: \(session.mode.permissionDescription(for: .command))
            canSudo: \(session.mode.permissionDescription(for: .sudo))
        Main agent-loop iteration limit: \(limitString)
        """
    }
}

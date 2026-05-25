//
//  Tool.swift
//  
//
//  Created by Ethan Brown on 3/19/26.
//

import Foundation

protocol Tool {
    var name: String { get }
    func schema() -> [String: Any]
    func execute(args: [String: Any]) async -> String
}

class ExampleTool: Tool {
    let name = "example_tool"

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Example tool description demonstrating the tools use, operations, and when it should be called.",
                "parameters": [
                    "type": "object",
                    "required": [],
                    "properties": [
                        "example_function_parameter": [
                            "type": "string",
                            "description": ""
                        ]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String : Any]) async -> String {
        guard let _ = args["example_function_parameter"] as? String else {
            return "Error: No parameter provided."
        }
        
        // Actual execution of tool call and a returned string of the result or error
        return ""
    }
}

class ExampleChatAwareTool: ChatSessionAware {
    let name = "example_tool"
    private var session: ChatSessionInfo?

    func setSession(_ session: ChatSessionInfo) {
        self.session = session
    }

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Example tool description demonstrating the tools use, operations, and when it should be called.",
                "parameters": [
                    "type": "object",
                    "required": [],
                    "properties": [
                        "example_function_parameter": [
                            "type": "string",
                            "description": ""
                        ]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String : Any]) async -> String {
        guard let _ = args["example_function_parameter"] as? String else {
            return "Error: No parameter provided."
        }
        guard let session = session else {
            return "Invalid chat session. Developer error."
        }

        do {
            // Use of ToolPermissionGuard function(s) to check if action allowed inside this chat-session
            let request = PermissionRequest(action: .command)
            try session.mode.guardRequest(request, session: session) // Example check
        } catch {
            return String(describing: error)
        }
        
        // Actual execution of tool call and a returned string of the result or error
        return ""
    }
}

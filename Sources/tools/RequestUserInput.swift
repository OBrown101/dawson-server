//
//  RequestUserInput.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/10/26.
//

class RequestUserInput: Tool {
    let name = "request_user_input"
    
    func openAISchema() -> [String: Any] {
        return [
            "name": name,
            "description": "Pauses main agent loop and requests input from the user. Used for additional information, answer to questions, or any other input from the user.",
            "parameters": [
                "type": "object",
                "properties": [
                    "prompt": [
                        "type": "string",
                        "description": "What to ask the user"
                    ]
                ],
                "required": ["prompt"]
            ]
        ]
    }
    
    func anthropicSchema() -> [String: Any] {
        return [
            "name": name,
            "description": "Pauses main agent loop and requests input from the user. Used for additional information, answer to questions, or any other input from the user.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "prompt": [
                        "type": "string",
                        "description": "What to ask the user"
                    ]
                ],
                "required": ["prompt"]
            ]
        ]
    }
    
    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Pauses main agent loop and requests input from the user. Used for additional information, answer to questions, or any other input from the user.",
                "parameters": [
                    "type": "object",
                    "required": ["prompt"],
                    "properties": [
                        "prompt": [
                            "type": "string",
                            "description": "What to ask the user"
                        ]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        // Function not used since direct-call utilized in main agent-loop
        return ""
    }
}

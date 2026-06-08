//
//  Tool.swift
//  
//
//  Created by Ethan Brown on 3/19/26.
//

import Foundation

protocol Tool {
    var name: String { get }
    func ollamaSchema() -> [String: Any]
    func openAISchema() -> [String: Any]
    func anthropicSchema() -> [String: Any]
    func execute(args: [String: Any]) async -> String
}

class ExampleTool: Tool {
    let name = "example_tool"

    func openAISchema() -> [String : Any] {
        return [:]
    }
    
    func anthropicSchema() -> [String : Any] {
        return [:]
    }
    
    func ollamaSchema() -> [String: Any] {
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

class ExamplePermissionAwareTool: PermissionAware {
    let name = "example_tool"
    
    func permissionRequests(args: [String : Any]) -> [PermissionRequest] {
        return [
            PermissionRequest(action: .read)    // Example permission check
        ]
    }
    
    func openAISchema() -> [String : Any] {
        return [
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
    }

    func anthropicSchema() -> [String : Any] {
        return [
            "name": name,
            "description": "Example tool description demonstrating the tools use, operations, and when it should be called.",
            "input_schema": [
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
    }

    func ollamaSchema() -> [String: Any] {
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

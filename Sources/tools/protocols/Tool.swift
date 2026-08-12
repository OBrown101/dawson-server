//
//  Tool.swift
//  DAWSON
//
//  Created by Ethan Brown on 3/19/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

protocol Tool {
    static var name: String { get }
    func ollamaSchema() -> [String: Any]
    func openAISchema() -> [String: Any]
    func anthropicSchema() -> [String: Any]
    func execute(args: [String: Any]) async -> String
}

extension Tool {
    var instanceName: String {
        Self.name
    }
}

class ExampleTool: Tool {
    static let name = "example_tool"

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
                "name": ExampleTool.name,
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
    static let name = "example_permission_aware_tool"
    
    func permissionRequests(args: [String : Any]) -> [PermissionRequest] {
        return [
            PermissionRequest(action: .read)    // Example permission check
        ]
    }
    
    func openAISchema() -> [String : Any] {
        return [
            "name": ExamplePermissionAwareTool.name,
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
            "name": ExamplePermissionAwareTool.name,
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
                "name": ExamplePermissionAwareTool.name,
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

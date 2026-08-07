//
//  MempalaceListWings.swift
//
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation

class MempalaceListWings: Tool {
    static let name = "mempalace_list_wings"
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": MempalaceListWings.name,
            "description": "List all wings with drawer counts",
            "parameters": [
                "type": "object",
                "properties": [:],
                "required": []
            ]
        ]
    }
    
    func anthropicSchema() -> [String : Any] {
        return [
            "name": MempalaceListWings.name,
            "description": "List all wings with drawer counts",
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
                "name": MempalaceListWings.name,
                "description": "List all wings with drawer counts",
                "parameters": [
                    "type": "object",
                    "required": [],
                    "properties": [:]
                ]
            ]
        ]
    }
    
    func execute(args: [String: Any]) async -> String {
        return await MempalaceMemory.shared.mempalaceExec(name: MempalaceListWings.name, args: args)
    }
}

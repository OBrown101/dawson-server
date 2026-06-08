//
//  MempalaceOverview.swift
//
//
//  Created by Ethan Brown on 4/27/26.
//

import Foundation

class MempalaceStatus: Tool {
    let name = "mempalace_status"
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": name,
            "description": "Palace overview — total drawers, wing and room counts",
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
            "description": "Palace overview — total drawers, wing and room counts",
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
                "description": "Palace overview — total drawers, wing and room counts",
                "parameters": [
                    "type": "object",
                    "required": [],
                    "properties": [:]
                ]
            ]
        ]
    }
    
    func execute(args: [String: Any]) -> String {
        return MempalaceMemory.shared.mempalaceExec(name: name, args: args)
    }
}

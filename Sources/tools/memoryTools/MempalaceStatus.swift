//
//  MempalaceOverview.swift
//
//
//  Created by Ethan Brown on 4/27/26.
//

import Foundation

class MempalaceStatus: Tool {
    static let name = "mempalace_status"
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": MempalaceStatus.name,
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
            "name": MempalaceStatus.name,
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
                "name": MempalaceStatus.name,
                "description": "Palace overview — total drawers, wing and room counts",
                "parameters": [
                    "type": "object",
                    "required": [],
                    "properties": [:]
                ]
            ]
        ]
    }
    
    func execute(args: [String: Any]) async -> String {
        return await MempalaceMemory.shared.mempalaceExec(name: MempalaceStatus.name, args: args)
    }
}

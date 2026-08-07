//
//  MempalaceKgStats.swift
//
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation

class MempalaceKgStats: Tool {
    static let name = "mempalace_kg_stats"
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": MempalaceKgStats.name,
            "description": "Knowledge graph overview: entities, triples, current vs expired facts, relationship types.",
            "parameters": [
                "type": "object",
                "properties": [:],
                "required": []
            ]
        ]
    }
    
    func anthropicSchema() -> [String : Any] {
        return [
            "name": MempalaceKgStats.name,
            "description": "Knowledge graph overview: entities, triples, current vs expired facts, relationship types.",
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
                "name": MempalaceKgStats.name,
                "description": "Knowledge graph overview: entities, triples, current vs expired facts, relationship types.",
                "parameters": [
                    "type": "object",
                    "required": [],
                    "properties": [:]
                ]
            ]
        ]
    }
    
    func execute(args: [String: Any]) async -> String {
        return await MempalaceMemory.shared.mempalaceExec(name: MempalaceKgStats.name, args: args)
    }
}

//
//  MempalaceKgTimeline.swift
//
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation

class MempalaceKgTimeline: Tool {
    static let name = "mempalace_kg_timeline"
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": MempalaceKgTimeline.name,
            "description": "Chronological timeline of facts. Shows the story of an entity (or everything) in order.",
            "parameters": [
                "type": "object",
                "properties": [
                    "entity": [
                        "type": "string",
                        "description": "Entity to get timeline for (optional — omit for full timeline)"
                    ]
                ],
                "required": []
            ]
        ]
    }
    
    func anthropicSchema() -> [String : Any] {
        return [
            "name": MempalaceKgTimeline.name,
            "description": "Chronological timeline of facts. Shows the story of an entity (or everything) in order.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "entity": [
                        "type": "string",
                        "description": "Entity to get timeline for (optional — omit for full timeline)"
                    ]
                ],
                "required": []
            ]
        ]
    }
    
    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": MempalaceKgTimeline.name,
                "description": "Chronological timeline of facts. Shows the story of an entity (or everything) in order.",
                "parameters": [
                    "type": "object",
                    "required": [],
                    "properties": [
                        "entity": [
                            "type": "string",
                            "description": "Entity to get timeline for (optional — omit for full timeline)"
                        ]
                    ]
                ]
            ]
        ]
    }
    
    func execute(args: [String: Any]) async -> String {
        return await MempalaceMemory.shared.mempalaceExec(name: MempalaceKgTimeline.name, args: args)
    }
}

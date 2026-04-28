//
//  MempalaceKgStats.swift
//
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation

class MempalaceKgStats: Tool {
    let name = "mempalace_kg_stats"
    
    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Knowledge graph overview: entities, triples, current vs expired facts, relationship types.",
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

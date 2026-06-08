//
//  MempalaceGraphStats.swift
//
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation

class MempalaceGraphStats: Tool {
    let name = "mempalace_graph_stats"
    
    func openAISchema() -> [String : Any] {
        return [
            "name": name,
            "description": "Palace graph overview: total rooms, tunnel connections, edges between wings.",
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
            "description": "Palace graph overview: total rooms, tunnel connections, edges between wings.",
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
                "description": "Palace graph overview: total rooms, tunnel connections, edges between wings.",
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

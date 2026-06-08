//
//  MempalaceKgQuery.swift
//
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation

class MempalaceKgQuery: Tool {
    let name = "mempalace_kg_query"
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": name,
            "description": "Query the knowledge graph for an entity's relationships. Returns typed facts with temporal validity. E.g. 'Max' → child_of Alice, loves chess, does swimming. Filter by date with as_of to see what was true at a point in time.",
            "parameters": [
                "type": "object",
                "required": ["entity"],
                "properties": [
                    "entity": [
                        "type": "string",
                        "description": "Entity to query (e.g. 'Max', 'MyProject', 'Alice')"
                    ],
                    "as_of": [
                        "type": "string",
                        "description": "Date filter — only facts valid at this date (YYYY-MM-DD, optional)"
                    ],
                    "direction": [
                        "type": "string",
                        "description": "outgoing (entity→?), incoming (?→entity), or both (default: both)"
                    ]
                ]
            ]
        ]
    }
    
    func anthropicSchema() -> [String : Any] {
        return [
            "name": name,
            "description": "Query the knowledge graph for an entity's relationships. Returns typed facts with temporal validity. E.g. 'Max' → child_of Alice, loves chess, does swimming. Filter by date with as_of to see what was true at a point in time.",
            "input_schema": [
                "type": "object",
                "required": ["entity"],
                "properties": [
                    "entity": [
                        "type": "string",
                        "description": "Entity to query (e.g. 'Max', 'MyProject', 'Alice')"
                    ],
                    "as_of": [
                        "type": "string",
                        "description": "Date filter — only facts valid at this date (YYYY-MM-DD, optional)"
                    ],
                    "direction": [
                        "type": "string",
                        "description": "outgoing (entity→?), incoming (?→entity), or both (default: both)"
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
                "description": "Query the knowledge graph for an entity's relationships. Returns typed facts with temporal validity. E.g. 'Max' → child_of Alice, loves chess, does swimming. Filter by date with as_of to see what was true at a point in time.",
                "parameters": [
                    "type": "object",
                    "required": ["entity"],
                    "properties": [
                        "entity": [
                            "type": "string",
                            "description": "Entity to query (e.g. 'Max', 'MyProject', 'Alice')"
                        ],
                        "as_of": [
                            "type": "string",
                            "description": "Date filter — only facts valid at this date (YYYY-MM-DD, optional)"
                        ],
                        "direction": [
                            "type": "string",
                            "description": "outgoing (entity→?), incoming (?→entity), or both (default: both)"
                        ]
                    ]
                ]
            ]
        ]
    }
    
    func execute(args: [String: Any]) -> String {
        return MempalaceMemory.shared.mempalaceExec(name: name, args: args)
    }
}

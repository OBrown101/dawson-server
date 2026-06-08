//
//  MempalaceKgAdd.swift
//  
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation

class MempalaceKgAdd: Tool {
    let name = "mempalace_kg_add"
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": name,
            "description": "Add a fact to the knowledge graph. Subject → predicate → object with optional time window. E.g. ('Max', 'started_school', 'Year 7', valid_from='2026-09-01').",
            "parameters": [
                "type": "object",
                "required": ["subject", "predicate", "object"],
                "properties": [
                    "subject": [
                        "type": "string",
                        "description": "The entity doing/being something"
                    ],
                    "predicate": [
                        "type": "string",
                        "description": "The relationship type (e.g. 'loves', 'works_on', 'daughter_of')"
                    ],
                    "object": [
                        "type": "string",
                        "description": "The entity being connected to"
                    ],
                    "valid_from": [
                        "type": "string",
                        "description": "When this became true (YYYY-MM-DD, optional)"
                    ],
                    "source_closet": [
                        "type": "string",
                        "description": "Closet ID where this fact appears (optional)"
                    ]
                ]
            ]
        ]
    }
    
    func anthropicSchema() -> [String : Any] {
        return [
            "name": name,
            "description": "Add a fact to the knowledge graph. Subject → predicate → object with optional time window. E.g. ('Max', 'started_school', 'Year 7', valid_from='2026-09-01').",
            "input_schema": [
                "type": "object",
                "required": ["subject", "predicate", "object"],
                "properties": [
                    "subject": [
                        "type": "string",
                        "description": "The entity doing/being something"
                    ],
                    "predicate": [
                        "type": "string",
                        "description": "The relationship type (e.g. 'loves', 'works_on', 'daughter_of')"
                    ],
                    "object": [
                        "type": "string",
                        "description": "The entity being connected to"
                    ],
                    "valid_from": [
                        "type": "string",
                        "description": "When this became true (YYYY-MM-DD, optional)"
                    ],
                    "source_closet": [
                        "type": "string",
                        "description": "Closet ID where this fact appears (optional)"
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
                "description": "Add a fact to the knowledge graph. Subject → predicate → object with optional time window. E.g. ('Max', 'started_school', 'Year 7', valid_from='2026-09-01').",
                "parameters": [
                    "type": "object",
                    "required": ["subject", "predicate", "object"],
                    "properties": [
                        "subject": [
                            "type": "string",
                            "description": "The entity doing/being something"
                        ],
                        "predicate": [
                            "type": "string",
                            "description": "The relationship type (e.g. 'loves', 'works_on', 'daughter_of')"
                        ],
                        "object": [
                            "type": "string",
                            "description": "The entity being connected to"
                        ],
                        "valid_from": [
                            "type": "string",
                            "description": "When this became true (YYYY-MM-DD, optional)"
                        ],
                        "source_closet": [
                            "type": "string",
                            "description": "Closet ID where this fact appears (optional)"
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

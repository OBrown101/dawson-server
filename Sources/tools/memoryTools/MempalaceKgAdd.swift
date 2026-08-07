//
//  MempalaceKgAdd.swift
//
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation

class MempalaceKgAdd: Tool {
    static let name = "mempalace_kg_add"
    
    private let toolDescription = """
    Add a fact to the knowledge graph. Subject → predicate → object with optional time window. E.g. ('Max', 'started_school', 'Year 7', valid_from='2026-09-01'). Pass valid_to to backfill an already-ended historical fact in a single call.
    """
    
    private let parameterSchema: [String: Any] = [
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
                "description": "When this became true (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SSZ, optional)"
            ],
            "valid_to": [
                "type": "string",
                "description": "When this stopped being true (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SSZ, optional). Use for backfilling already-ended historical facts."
            ],
            "source_closet": [
                "type": "string",
                "description": "Closet ID where this fact appears (optional)"
            ],
            "source_drawer_id": [
                "type": "string",
                "description": "Drawer ID the fact was extracted from (optional, provenance)"
            ],
            "source_file": [
                "type": "string",
                "description": "Source file path the fact was extracted from (optional)"
            ]
        ]
    ]
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": MempalaceKgAdd.name,
            "description": toolDescription,
            "parameters": parameterSchema
        ]
    }

    func anthropicSchema() -> [String : Any] {
        return [
            "name": MempalaceKgAdd.name,
            "description": toolDescription,
            "input_schema": parameterSchema
        ]
    }

    func ollamaSchema() -> [String : Any] {
        return [
            "type": "function",
            "function": [
                "name": MempalaceKgAdd.name,
                "description": toolDescription,
                "parameters": parameterSchema
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        return await MempalaceMemory.shared.mempalaceExec(name: MempalaceKgAdd.name, args: args)
    }
}

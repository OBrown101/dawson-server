//
//  MempalaceSearch.swift
//  DAWSON
//
//  Created by Ethan Brown on 4/27/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

class MempalaceSearch: Tool {
    static let name = "mempalace_search"
    
    private let toolDescription = """
    Semantic search. Returns verbatim drawer content with similarity scores. IMPORTANT: 'query' must contain ONLY search keywords (max 250 chars). Use 'context' for background. Results with cosine distance > max_distance are filtered out.
    """
    
    private let parameterSchema: [String: Any] = [
        "type": "object",
        "required": ["query"],
        "properties": [
            "query": [
                "type": "string",
                "maxLength": 250,
                "description": "Short search query ONLY — keywords or a question. Max 250 chars."
            ],
            "wing": [
                "type": "string",
                "description": "Filter results to a specific wing (project or team) in the Memory Palace. Use the wing name as stored in the palace database."
            ],
            "room": [
                "type": "string",
                "description": "Filter results to a specific room within the chosen wing. Provide the exact room name as defined in the palace schema."
            ],
            "limit": [
                "type": "integer",
                "minimum": 1,
                "maximum": 100,
                "description": "Max results (default 5)"
            ],
            "context": [
                "type": "string",
                "description": "Background context for the search (optional). NOT used for embedding — only for future re-ranking."
            ],
            "max_distance": [
                "type": "number",
                "description": "Max cosine distance threshold (0=identical, 2=opposite). Results further than this are dropped. Lower = stricter. Default 1.5. Set to 0 to disable."
            ],
            "source_file": [
                "type": "string",
                "description": "Filter to one exact source file (optional). Matches the full stored path exactly — pass the value from a result's 'source_path' field, not the displayed basename."
            ]
        ]
    ]
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": MempalaceSearch.name,
            "description": toolDescription,
            "parameters": parameterSchema
        ]
    }

    func anthropicSchema() -> [String : Any] {
        return [
            "name": MempalaceSearch.name,
            "description": toolDescription,
            "input_schema": parameterSchema
        ]
    }

    func ollamaSchema() -> [String : Any] {
        return [
            "type": "function",
            "function": [
                "name": MempalaceSearch.name,
                "description": toolDescription,
                "parameters": parameterSchema
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        return await MempalaceMemory.shared.mempalaceExec(name: MempalaceSearch.name, args: args)
    }
}

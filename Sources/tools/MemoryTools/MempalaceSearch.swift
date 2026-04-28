//
//  MempalaceSearch.swift
//  
//
//  Created by Ethan Brown on 4/27/26.
//

import Foundation

class MempalaceSearch: Tool {
    let name = "mempalace_search"
    
    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Semantic search with wing/room filters",
                "parameters": [
                    "type": "object",
                    "required": ["query"],
                    "properties": [
                        "query": [
                            "type": "string",
                            "description": "Text or context to search for"
                        ],
                        "wing": [
                            "type": "string",
                            "description": "Filter results to a specific wing (project or team) in the Memory Palace. Use the wing name as stored in the palace database."
                        ],
                        "room": [
                            "type": "string",
                            "description": "Filter results to a specific room within the chosen wing. Provide the exact room name as defined in the palace schema."
                        ],
                        "n_results": [
                            "type": "integer",
                            "description": "Maximum number of search results to return."
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

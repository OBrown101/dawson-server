//
//  MempalaceKgInvalidate.swift
//  
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation

class MempalaceKgInvalidate: Tool {
    let name = "mempalace_kg_invalidate"
    
    func openAISchema() -> [String : Any] {
        return [
            "name": name,
            "description": "Mark a fact as no longer true. E.g. ankle injury resolved, job ended, moved house.",
            "parameters": [
                "type": "object",
                "properties": [
                    "subject": [
                        "type": "string",
                        "description": "Entity"
                    ],
                    "predicate": [
                        "type": "string",
                        "description": "Relationship"
                    ],
                    "object": [
                        "type": "string",
                        "description": "Connected entity"
                    ],
                    "ended": [
                        "type": "string",
                        "description": "When it stopped being true (YYYY‑MM‑DD, default: today)"
                    ]
                ],
                "required": ["subject", "predicate", "object"]
            ]
        ]
    }
    
    func anthropicSchema() -> [String : Any] {
        return [
            "name": name,
            "description": "Mark a fact as no longer true. E.g. ankle injury resolved, job ended, moved house.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "subject": [
                        "type": "string",
                        "description": "Entity"
                    ],
                    "predicate": [
                        "type": "string",
                        "description": "Relationship"
                    ],
                    "object": [
                        "type": "string",
                        "description": "Connected entity"
                    ],
                    "ended": [
                        "type": "string",
                        "description": "When it stopped being true (YYYY‑MM‑DD, default: today)"
                    ]
                ],
                "required": ["subject", "predicate", "object"]
            ]
        ]
    }
    
    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Mark a fact as no longer true. E.g. ankle injury resolved, job ended, moved house.",
                "parameters": [
                    "type": "object",
                    "required": ["subject", "predicate", "object"],
                    "properties": [
                        "subject": [
                            "type": "string",
                            "description": "Entity"
                        ],
                        "predicate": [
                            "type": "string",
                            "description": "Relationship"
                        ],
                        "object": [
                            "type": "string",
                            "description": "Connected entity"
                        ],
                        "ended": [
                            "type": "string",
                            "description": "When it stopped being true (YYYY-MM-DD, default: today)"
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

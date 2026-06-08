//
//  MempalaceDeleteDrawer.swift
//
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation

class MempalaceDeleteDrawer: Tool {
    let name = "mempalace_delete_drawer"
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": name,
            "description": "Delete a drawer by ID. Irreversible.",
            "parameters": [
                "type": "object",
                "required": ["drawer_id"],
                "properties": [
                    "drawer_id": [
                        "type": "string",
                        "description": "ID of the drawer to delete"
                    ]
                ]
            ]
        ]
    }
    
    func anthropicSchema() -> [String : Any] {
        return [
            "name": name,
            "description": "Delete a drawer by ID. Irreversible.",
            "input_schema": [
                "type": "object",
                "required": ["drawer_id"],
                "properties": [
                    "drawer_id": [
                        "type": "string",
                        "description": "ID of the drawer to delete"
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
                "description": "Delete a drawer by ID. Irreversible.",
                "parameters": [
                    "type": "object",
                    "required": ["drawer_id"],
                    "properties": [
                        "drawer_id": [
                            "type": "string",
                            "description": "ID of the drawer to delete"
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

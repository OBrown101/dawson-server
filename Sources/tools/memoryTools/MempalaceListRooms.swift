//
//  MempalaceListRooms.swift
//  DAWSON
//
//  Created by Ethan Brown on 4/28/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

class MempalaceListRooms: Tool {
    static let name = "mempalace_list_rooms"
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": MempalaceListRooms.name,
            "description": "List rooms within a wing (or all rooms if no wing given)",
            "parameters": [
                "type": "object",
                "properties": [
                    "wing": [
                        "type": "string",
                        "description": "Wing to list rooms for (optional)"
                    ]
                ],
                "required": []
            ]
        ]
    }

    func anthropicSchema() -> [String : Any] {
        return [
            "name": MempalaceListRooms.name,
            "description": "List rooms within a wing (or all rooms if no wing given)",
            "input_schema": [
                "type": "object",
                "properties": [
                    "wing": [
                        "type": "string",
                        "description": "Wing to list rooms for (optional)"
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
                "name": MempalaceListRooms.name,
                "description": "List rooms within a wing (or all rooms if no wing given)",
                "parameters": [
                    "type": "object",
                    "required": [],
                    "properties": [
                        "wing": [
                            "type": "string",
                            "description": "Wing to list rooms for (optional)"
                        ]
                    ]
                ]
            ]
        ]
    }
    
    func execute(args: [String: Any]) async -> String {
        return await MempalaceMemory.shared.mempalaceExec(name: MempalaceListRooms.name, args: args)
    }
}

//
//  MempalaceDrawerTools.swift
//  DAWSON
//
//  Created by Ethan Brown on 4/28/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

class MempalaceAddDrawer: Tool {
    static let name = "mempalace_add_drawer"
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": MempalaceAddDrawer.name,
            "description": "File verbatim content into the palace. Checks for duplicates first.",
            "parameters": [
                "type": "object",
                "required": ["wing", "room", "content"],
                "properties": [
                    "wing": [
                        "type": "string",
                        "description": "Wing (project name)"
                    ],
                    "room": [
                        "type": "string",
                        "description": "Room (aspect: backend, decisions, meetings...)"
                    ],
                    "content": [
                        "type": "string",
                        "description": "Verbatim content to store — exact words, never summarized"
                    ],
                    "source_file": [
                        "type": "string",
                        "description": "Where this came from (optional)"
                    ],
                    "added_by": [
                        "type": "string",
                        "description": "Who is filing this (default: should be the agent's name who is filing it)"
                    ]
                ]
            ]
        ]
    }
    
    func anthropicSchema() -> [String : Any] {
        return [
            "name": MempalaceAddDrawer.name,
            "description": "File verbatim content into the palace. Checks for duplicates first.",
            "input_schema": [
                "type": "object",
                "required": ["wing", "room", "content"],
                "properties": [
                    "wing": [
                        "type": "string",
                        "description": "Wing (project name)"
                    ],
                    "room": [
                        "type": "string",
                        "description": "Room (aspect: backend, decisions, meetings...)"
                    ],
                    "content": [
                        "type": "string",
                        "description": "Verbatim content to store — exact words, never summarized"
                    ],
                    "source_file": [
                        "type": "string",
                        "description": "Where this came from (optional)"
                    ],
                    "added_by": [
                        "type": "string",
                        "description": "Who is filing this (default: should be the agent's name who is filing it)"
                    ]
                ]
            ]
        ]
    }
    
    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": MempalaceAddDrawer.name,
                "description": "File verbatim content into the palace. Checks for duplicates first.",
                "parameters": [
                    "type": "object",
                    "required": ["wing", "room", "content"],
                    "properties": [
                        "wing": [
                            "type": "string",
                            "description": "Wing (project name)"
                        ],
                        "room": [
                            "type": "string",
                            "description": "Room (aspect: backend, decisions, meetings...)"
                        ],
                        "content": [
                            "type": "string",
                            "description": "Verbatim content to store — exact words, never summarized"
                        ],
                        "source_file": [
                            "type": "string",
                            "description": "Where this came from (optional)"
                        ],
                        "added_by": [
                            "type": "string",
                            "description": "Who is filing this (default: should be the agent's name who is filing it)"
                        ]
                    ]
                ]
            ]
        ]
    }
    
    func execute(args: [String: Any]) async -> String {
        return await MempalaceMemory.shared.mempalaceExec(name: MempalaceAddDrawer.name, args: args)
    }
}

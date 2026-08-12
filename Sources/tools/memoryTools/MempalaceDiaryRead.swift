//
//  MempalaceDiaryRead.swift
//  DAWSON
//
//  Created by Ethan Brown on 4/27/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

class MempalaceDiaryRead: Tool {
    static let name = "mempalace_diary_read"

    private let toolDescription = """
    Read your recent diary entries (in AAAK). See what past versions of yourself recorded — your journal across sessions.
    """
    
    private let parameterSchema: [String: Any] = [
        "type": "object",
        "required": ["agent_name"],
        "properties": [
            "agent_name": [
                "type": "string",
                "description": "Your name — each agent gets their own diary wing"
            ],
            "last_n": [
                "type": "integer",
                "description": "Number of recent entries to read (default: 10)"
            ],
            "wing": [
                "type": "string",
                "description": "Wing to read diary entries from (optional). If omitted, reads from wing_{agent_name}."
            ]
        ]
    ]
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": MempalaceDiaryRead.name,
            "description": toolDescription,
            "parameters": parameterSchema
        ]
    }

    func anthropicSchema() -> [String : Any] {
        return [
            "name": MempalaceDiaryRead.name,
            "description": toolDescription,
            "input_schema": parameterSchema
        ]
    }

    func ollamaSchema() -> [String : Any] {
        return [
            "type": "function",
            "function": [
                "name": MempalaceDiaryRead.name,
                "description": toolDescription,
                "parameters": parameterSchema
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        return await MempalaceMemory.shared.mempalaceExec(name: MempalaceDiaryRead.name, args: args)
    }
}

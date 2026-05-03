//
//  MempalaceDiaryRead.swift
//
//
//  Created by Ethan Brown on 4/27/26.
//

import Foundation

class MempalaceDiaryRead: Tool {
    let name = "mempalace_diary_read"
    
    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Read your recent diary entries (in AAAK). See what past versions of yourself recorded — your journal across sessions.",
                "parameters": [
                    "type": "object",
                    "required": ["agent_name"],
                    "properties": [
                        "agent_name": [
                            "type": "string",
                            "description": "The agent's internal name — each agent gets their own diary wing"
                        ],
                        "last_n": [
                            "type": "integer",
                            "description": "Number of recent entries to read (use 10 as default if unsure)"
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

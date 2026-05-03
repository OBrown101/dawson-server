//
//  MempalaceDrawerTools.swift
//
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation

class MempalaceAddDrawer: Tool {
    let name = "mempalace_add_drawer"
    
    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
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
    
    func execute(args: [String: Any]) -> String {
        return MempalaceMemory.shared.mempalaceExec(name: name, args: args)
    }
}

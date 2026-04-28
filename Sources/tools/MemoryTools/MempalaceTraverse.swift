//
//  MempalaceTraverse.swift
//
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation

class MempalaceTraverse: Tool {
    let name = "mempalace_traverse"
    
    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Walk the palace graph from a room. Shows connected ideas across wings — the tunnels. Like following a thread through the palace: start at 'chromadb-setup' in wing_code, discover it connects to wing_myproject (planning) and wing_user (feelings about it).",
                "parameters": [
                    "type": "object",
                    "required": ["start_room"],
                    "properties": [
                        "start_room": [
                            "type": "string",
                            "description": "Room to start from (e.g. 'chromadb-setup', 'riley-school')"
                        ],
                        "max_hops": [
                            "type": "integer",
                            "description": "How many connections to follow (default: 2)"
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

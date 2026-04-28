//
//  MempalaceListRooms.swift
//
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation

class MempalaceListRooms: Tool {
    let name = "mempalace_list_rooms"
    
    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
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
    
    func execute(args: [String: Any]) -> String {
        return MempalaceMemory.shared.mempalaceExec(name: name, args: args)
    }
}

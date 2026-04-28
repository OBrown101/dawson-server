//
//  MempalaceCheckDuplicate.swift
//
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation

class MempalaceCheckDuplicate: Tool {
    let name = "mempalace_check_duplicate"
    
    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Check if content already exists in the palace before filing",
                "parameters": [
                    "type": "object",
                    "required": ["content"],
                    "properties": [
                        "content": [
                            "type": "string",
                            "description": "Content to check"
                        ],
                        "threshold": [
                            "type": "number",
                            "description": "Similarity threshold 0-1 (default 0.9)"
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

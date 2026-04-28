//
//  MempalaceListWings.swift
//
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation

class MempalaceListWings: Tool {
    let name = "mempalace_list_wings"
    
    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "List all wings with drawer counts",
                "parameters": [
                    "type": "object",
                    "required": [],
                    "properties": [:]
                ]
            ]
        ]
    }
    
    func execute(args: [String: Any]) -> String {
        return MempalaceMemory.shared.mempalaceExec(name: name, args: args)
    }
}

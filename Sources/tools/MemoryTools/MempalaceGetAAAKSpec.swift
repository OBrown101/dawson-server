//
//  MempalaceGetAAAKSpec.swift
//
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation

class MempalaceGetAAAKSpec: Tool {
    let name = "mempalace_get_aaak_spec"
    
    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Get the AAAK dialect specification — the compressed memory format MemPalace uses. Call this if you need to read or write AAAK-compressed memories.",
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

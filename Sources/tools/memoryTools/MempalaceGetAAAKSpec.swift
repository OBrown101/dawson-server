//
//  MempalaceGetAAAKSpec.swift
//
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation

class MempalaceGetAAAKSpec: Tool {
    static let name = "mempalace_get_aaak_spec"
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": MempalaceGetAAAKSpec.name,
            "description": "Get the AAAK dialect specification — the compressed memory format MemPalace uses. Call this if you need to read or write AAAK-compressed memories.",
            "parameters": [
                "type": "object",
                "properties": [:],
                "required": []
            ]
        ]
    }
    
    func anthropicSchema() -> [String : Any] {
        return [
            "name": MempalaceGetAAAKSpec.name,
            "description": "Get the AAAK dialect specification — the compressed memory format MemPalace uses. Call this if you need to read or write AAAK-compressed memories.",
            "input_schema": [
                "type": "object",
                "properties": [:],
                "required": []
            ]
        ]
    }
    
    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": MempalaceGetAAAKSpec.name,
                "description": "Get the AAAK dialect specification — the compressed memory format MemPalace uses. Call this if you need to read or write AAAK-compressed memories.",
                "parameters": [
                    "type": "object",
                    "required": [],
                    "properties": [:]
                ]
            ]
        ]
    }
    
    func execute(args: [String: Any]) async -> String {
        return await MempalaceMemory.shared.mempalaceExec(name: MempalaceGetAAAKSpec.name, args: args)
    }
}

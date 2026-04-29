//
//  MempalaceMemory.swift
//
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation
import PythonKit

class MempalaceMemory {
    static let shared = MempalaceMemory()
    
    let scriptPath = "pythonHandlers/mempalace_handler.py"
    
    func mempalaceExec(name: String, args: [String: Any]) -> String {
        /*
         MCP tools/call format:
         {
             "method": "tools/call",
             "id": UUID,
             "params": {
                 "name": tool_name,
                 "arguments": { ... }
             }
         }
         */
        let mcpPayload: [String: Any] = [
            "method": "tools/call",
            "id": UUID().uuidString,
            "params": [
                "name": name,
                "arguments": args
            ]
        ]
        
        let result = PythonHandler.shared.call(module: "mempalace_handler", function: "mcp_wrapper", args: mcpPayload)
        return String(describing: result)
    }
}

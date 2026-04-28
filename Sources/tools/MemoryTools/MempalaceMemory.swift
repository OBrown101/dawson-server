//
//  MempalaceMemory.swift
//
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation

class MempalaceMemory {
    static let shared = MempalaceMemory()
    
    let scriptPath = "pythonHandlers/mempalace_handler.py"
    
    func mempalaceExec(name: String, args: [String: Any]) -> String {
        guard let handler = try? PythonHandler(script: scriptPath) else {
            print("Python handler unavailable.")
            return "Python handler unavailable. Try another way or ask user for next steps."
        }
        
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
        
        do {
            let result = try handler.call(method: "mcp_wrapper", params: mcpPayload)
//            guard let result = result else {
//                return result?["error"] as? String ?? "Failed call mcp_wrapper: unknown cause. Try another way or ask user for next steps."
//            }
//            
//            if let jsonData = try? JSONSerialization.data(withJSONObject: result, options: []) {
//                return String(data: jsonData, encoding: .utf8) ?? "Conversion failed"
//            }
            
            return String(describing: result)
        } catch {
            print("Failed to call mcp_wrapper: \(error.localizedDescription)")
            return "Failed to call mcp_wrapper: \(error.localizedDescription). Try another way or ask user for next steps."
        }
    }
}

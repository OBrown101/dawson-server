//
//  MempalaceMemory.swift
//
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation
import PythonKit
import MCP
import System


class MempalaceMemory: @unchecked Sendable {
    static let shared = MempalaceMemory()
    
    static let mempalacePath = DAWSON.root.appendingPathComponent(".mempalace")
    static let palacePath = mempalacePath.appendingPathComponent("palace")
    
    func mempalaceExec(name: String, args: [String: Any]) -> String {
        setenv("MEMPALACE_PALACE_PATH", MempalaceMemory.palacePath.path, 1)
        
        let mcpPayload: [String: Any] = [
            "method": "tools/call",
            "id": UUID().uuidString,
            "params": [
                "name": name,
                "arguments": args
            ]
        ]
        
        do {
            let result = try PythonHandler.shared.call(moduleName: "mempalace.mcp_server", functionName: "handle_request", args: mcpPayload)
            return String(describing: result)
        } catch {
            print("MEMPALACE FULL ERROR ↓↓↓")
            print(error)   // full PythonKit error incl. traceback, unclipped
            return "Mempalace \(name) failed: \(error)"
        }
    }
    
    func mineConversations(path: String) throws -> PythonProcess {
        let args = [
            "-m", "mempalace",
            "--palace", MempalaceMemory.palacePath.path,
            "mine",
            path,
            "--mode", "convos"
        ]

        return try PythonHandler.shared.startPythonProcess(
            scriptPath: PythonEnv.pythonExecPath,
            arguments: args,
            inputPipe: Pipe(),
            outputPipe: Pipe(),
            errorPipe: Pipe()
        )
    }
    
    func getStatus() -> String {
        return mempalaceExec(name: "mempalace_status", args: [:])
    }
}

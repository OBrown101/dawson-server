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
    
    func addConvHistory(messages: [Message], agent: Agent.AgentType) {
        guard let jsonData = try? JSONEncoder().encode(messages),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("Failed to add conversation history.")
            return
        }
        
        let args: [String: Any] = [
            "wing": agent.name,
            "room": "conversations",
            "content": jsonString,
            "added_by": agent.name
        ]
        
        let result = mempalaceExec(name: "mempalace_add_drawer", args: args)
        print("addConvHistory: " + String(describing: result))
    }
    
    func getPromptContext(query: String, wing: String? = nil, room: String? = nil, nResults: Int = 8) -> String {
        var args: [String: Any] = [
            "query": query,
            "n_results": nResults
        ]
        
        if let wing = wing {
            args["wing"] = wing
        }
        
        if let room = room {
            args["room"] = room
        }
        
        let context = mempalaceExec(name: "mempalace_search", args: args)
        
        return ("Memory retrieved based on user's prompt: ##\(context)##")
    }
     
}

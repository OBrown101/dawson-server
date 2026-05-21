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
    
    let palacePath = "\(DAWSON.root)/.mempalace"
    
    /*
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    
    func initMCP() {
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        self.inputPipe = inputPipe
        self.outputPipe = outputPipe
        self.errorPipe = errorPipe
        
        Task {
            do {
                let transport = StdioTransport(
                    input: FileDescriptor(rawValue: outputPipe.fileHandleForReading.fileDescriptor),
                    output: FileDescriptor(rawValue: inputPipe.fileHandleForWriting.fileDescriptor)
                )
                
                _ = try PythonHandler.shared.startPythonProcess(
                    scriptPath: "\(PythonEnv.pythonPackagesPath)/mempalace/mcp_server.py",
                    arguments: ["--palace", self.palacePath],
                    inputPipe: inputPipe,
                    outputPipe: outputPipe,
                    errorPipe: errorPipe
                )
                    
                try await MCPHandler.shared.registerServer(serverName: "mempalace") {
                    return transport
                }
            } catch {
                print("MempalaceMCP init failed: \(error)")
            }
        }
    }
    
    func mempalaceMCPExec(name: String, args: [String: Any]) async -> String {
        do {
            let content = try await MCPHandler.shared.callTool(
                serverName: "mempalace",
                toolName: name,
                arguments: args
            )
            
            return MCPHandler.shared.convToString(content)
        } catch {
            return "Mempalace \(name) failed: \(error)"
        }
    }
     */
    
    func mempalaceExec(name: String, args: [String: Any]) -> String {
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
    
    func getStatus() -> String {
        return mempalaceExec(name: "mempalace_status", args: [:])
    }
    
    func addConvHistory(messages: [Message], agent: AgentType) {
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

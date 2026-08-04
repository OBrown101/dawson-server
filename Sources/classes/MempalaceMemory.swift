//
//  MempalaceMemory.swift
//
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation
import AnyCodable
import PythonKit
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

extension MempalaceMemory {

    func execStructured(name: String, args: [String: Any]) async throws -> Any {
        setenv("MEMPALACE_PALACE_PATH", MempalaceMemory.palacePath.path, 1)

        let mcpPayload: [String: Any] = [
            "method": "tools/call",
            "id": UUID().uuidString,
            "params": [
                "name": name,
                "arguments": args
            ]
        ]

        let raw: Any = try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try PythonHandler.shared.call(
                        moduleName: "mempalace.mcp_server",
                        functionName: "handle_request",
                        args: mcpPayload
                    )
                    cont.resume(returning: PythonUtilities.fromPython(result))
                } catch {
                    cont.resume(throwing: MemoryError.pythonFailed("\(error)"))
                }
            }
        }

        return Self.unwrapMCPEnvelope(raw)
    }

    static func unwrapMCPEnvelope(_ raw: Any) -> Any {
        var current = raw

        if let dict = current as? [String: Any] {
            if let err = dict["error"] {
                return ["error": err]
            }
            if let result = dict["result"] {
                current = result
            }
        }

        if let dict = current as? [String: Any],
           let content = dict["content"] as? [[String: Any]],
           let text = content.first?["text"] as? String {
            // Tool payload is usually JSON serialized into the text block.
            if let data = text.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) {
                return parsed
            }
            return ["text": text]   // non-JSON tool output, pass through
        }

        return current
    }
}

extension MempalaceMemory {

    func overview(since: String?, limit: Int?) async throws -> Any {
        var status: Any = [:]
        do {
            status = try await execStructured(name: "mempalace_status", args: [:])
        } catch {
            status = ["error": "\(error)"]
        }

        var args: [String: Any] = ["limit": (limit ?? 25)]
        if let since {
            args["since"] = since
        }
        var recents: Any = []
        do {
            recents = try await execStructured(name: "mempalace_list_drawers", args: args)
        } catch {
            recents = ["error": "\(error)"]
        }

        return ["status": status, "recents": recents]
    }

    func listWings() async throws -> Any {
        try await execStructured(name: "mempalace_list_wings", args: [:])
    }

    func listRooms(wing: String) async throws -> Any {
        try await execStructured(name: "mempalace_list_rooms", args: ["wing": wing])
    }

    func pageEntries(wing: String?, room: String?, before: String?, limit: Int?) async throws -> Any {
        // Cursor pagination: pass oldest filed_at from previous page as `before` to fetch next one
        var args: [String: Any] = ["limit": (limit ?? 25)]
        if let wing {
            args["wing"] = wing
        }
        if let room {
            args["room"] = room
        }
        if let before {
            args["before"] = before
        }
        return try await execStructured(name: "mempalace_list_drawers", args: args)
    }

    func searchStructured(query: String, wing: String?, room: String?, nResults: Int) async throws -> Any {
        var args: [String: Any] = ["query": query, "n_results": nResults]
        if let wing {
            args["wing"] = wing
        }
        if let room {
            args["room"] = room
        }
        return try await execStructured(name: "mempalace_search", args: args)
    }

    func getEntry(drawerID: String) async throws -> Any {
        try await execStructured(name: "mempalace_get_drawer", args: ["drawer_id": drawerID])
    }

    func deleteEntry(drawerID: String) async throws -> Any {
        try await execStructured(name: "mempalace_delete_drawer", args: ["drawer_id": drawerID])
    }
}

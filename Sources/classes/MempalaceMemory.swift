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
            return try PythonHandler.shared.callString(moduleName: "mempalace.mcp_server", functionName: "handle_request", args: mcpPayload)
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
    
    private struct SendableJSON: @unchecked Sendable {
        let value: Any
    }

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

        let bridgeArgs: [String: Any] = [
            "module": "mempalace.mcp_server",
            "function": "handle_request",
            "args": mcpPayload
        ]

        let jsonString: String = try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let s = try PythonHandler.shared.callString(
                        moduleName: "dawson_bridge",
                        functionName: "call_json",
                        args: bridgeArgs
                    )
                    cont.resume(returning: s)
                } catch {
                    cont.resume(throwing: MemoryError.pythonFailed("\(error)"))
                }
            }
        }

        guard let data = jsonString.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data) else {
            throw MemoryError.badResponse("bridge returned non-JSON: \(jsonString.prefix(300))")
        }

        print("MEMPALACE RAW [\(name)]:", raw)   // keep until first good decode
        return MempalaceMemory.unwrapMCPEnvelope(raw)
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

    func overview(limit: Int?) async throws -> MemoryOverview {
        // Docs don't specify list_drawers ordering
        // (if oldest-first, flip to offset = max(total - limit, 0) using page.total, then reverse page.drawers)
        
        var overview = MemoryOverview(status: nil, recents: [])

        do {
            let raw = try await execStructured(name: "mempalace_status", args: [:])
            overview.status = try MempalaceMemory.decode(MemoryStatus.self, from: raw)
        } catch {
            overview.statusError = "\(error)"
        }

        do {
            let page = try await pageEntries(wing: nil, room: nil,
                                             limit: min(limit ?? 25, 100), offset: 0)
            overview.recents = page.drawers
        } catch {
            overview.recentsError = "\(error)"
        }

        return overview
    }

    func listWings() async throws -> MemoryWingList {
        let raw = try await execStructured(name: "mempalace_list_wings", args: [:])
        return try MempalaceMemory.decode(MemoryWingList.self, from: raw)
    }

    func listRooms(wing: String?) async throws -> MemoryRoomList {
        var args: [String: Any] = [:]
        if let wing { args["wing"] = wing }
        let raw = try await execStructured(name: "mempalace_list_rooms", args: args)
        return try MempalaceMemory.decode(MemoryRoomList.self, from: raw)
    }

    func pageEntries(wing: String?, room: String?, limit: Int?, offset: Int?) async throws -> MemoryDrawerPage {
        // Offset pagination per docs (limit ≤ 100, default 20).
        // Next page: offset = previous offset + drawers.count; done when offset + drawers.count >= total.
        
        var args: [String: Any] = [
            "limit": min(limit ?? 25, 100),
            "offset": max(offset ?? 0, 0)
        ]
        if let wing { args["wing"] = wing }
        if let room { args["room"] = room }
        let raw = try await execStructured(name: "mempalace_list_drawers", args: args)
        return try MempalaceMemory.decode(MemoryDrawerPage.self, from: raw)
    }

    func searchStructured(query: String, wing: String?, room: String?, limit: Int?) async throws -> MemorySearchResults {
        var args: [String: Any] = ["query": query, "limit": (limit ?? 8)]
        if let wing { args["wing"] = wing }
        if let room { args["room"] = room }
        let raw = try await execStructured(name: "mempalace_search", args: args)
        return try MempalaceMemory.decode(MemorySearchResults.self, from: raw)
    }

    func getEntry(drawerID: String) async throws -> MemoryDrawer {
        let raw = try await execStructured(name: "mempalace_get_drawer", args: ["drawer_id": drawerID])
        return try MempalaceMemory.decode(MemoryDrawer.self, from: raw)
    }

    func deleteEntry(drawerID: String) async throws -> MemoryDeleteResult {
        let raw = try await execStructured(name: "mempalace_delete_drawer", args: ["drawer_id": drawerID])
        return try MempalaceMemory.decode(MemoryDeleteResult.self, from: raw)
    }
}

extension MempalaceMemory {
    
    static func decode<T: Decodable>(_ type: T.Type, from any: Any) throws -> T {
        guard JSONSerialization.isValidJSONObject(any) else {
            throw MemoryError.badResponse("not a JSON object: \(Swift.type(of: any))")
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: any)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw MemoryError.badResponse("decoding \(T.self): \(error)")
        }
    }
}

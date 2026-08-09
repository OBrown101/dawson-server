//
//  MempalaceMemory.swift
//
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation
import AnyCodable
import System

class MempalaceMemory: @unchecked Sendable {
    static let shared = MempalaceMemory()
    
    static let mempalacePath = DAWSON.root.appendingPathComponent(".mempalace")
    static let palacePath = mempalacePath.appendingPathComponent("palace")
    
    private let server = MCPServerProcess(
        name: "mempalace",
        executable: PythonEnv.pythonExecPath,
        arguments: ["-m", "mempalace.mcp_server"],
        environment: [
            "PYTHONHOME": PythonEnv.pythonHome.path,
            "PYTHONUNBUFFERED": "1",
            "HOME": FileManager.default.homeDirectoryForCurrentUser.path,
            "PATH": PythonEnv.pythonHome.appendingPathComponent("bin").path + ":/usr/bin:/bin",
            "LANG": "C.UTF-8",
            "MEMPALACE_PALACE_PATH": MempalaceMemory.palacePath.path
        ]
    )
    
    func mempalaceExec(name: String, args: [String: Any]) async -> String {
        // For agent tool calls
        do {
            let raw = try await server.callTool(
                name: name,
                argumentsData: try JSONSerialization.data(withJSONObject: args)
            )
            return MempalaceMemory.stringify(unwrapMCPEnvelope(parse(raw)))
        } catch {
            print("MEMPALACE FULL ERROR ↓↓↓")
            print(error)
            return "Mempalace \(name) failed: \(error)"
        }
    }
    
    func execStructured(name: String, args: [String: Any]) async throws -> Any {
        // For use for Websocket client (e.g. Beakshield)
        do {
            let raw = try await server.callTool(
                name: name,
                argumentsData: try JSONSerialization.data(withJSONObject: args)
            )
            return unwrapMCPEnvelope(parse(raw))
        } catch let error as MCPProcessError {
            throw MemoryError.pythonFailed("\(error)")
        }
    }
    
    func listServerTools() async throws -> Any {
        parse(try await server.listTools())
    }
    
    func shutdown() async {
        await server.shutdown()
    }

    func mineConversations(
        path: String,
        wing: String? = nil,
        agent: String? = nil,
        dryRun: Bool = false,
        limit: Int = 0
    ) async throws -> MemoryMineResult {
        var args: [String: Any] = [
            "source": path,
            "mode": "convos",
            "dry_run": dryRun,
            "limit": limit
        ]
        if let wing { args["wing"] = wing }
        if let agent { args["agent"] = agent }

        do {
            let raw = try await server.callTool(
                name: "mempalace_mine",
                argumentsData: try JSONSerialization.data(withJSONObject: args),
                timeout: 1_800   // mining runs long; 30 min ceiling
            )
            return try MempalaceMemory.decode(MemoryMineResult.self, from: unwrapMCPEnvelope(parse(raw)))
        } catch let error as MCPProcessError {
            throw MemoryError.pythonFailed("\(error)")
        }
    }
    
    func getStatus() async -> String {
        return await mempalaceExec(name: "mempalace_status", args: [:])
    }
    
    private func parse(_ raw: String) -> Any {
        // Raw JSON-RPC line → Any (dict/array), or a wrapped error.
        guard let data = raw.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) else {
            return ["error": "non-JSON MCP response: \(raw.prefix(300))"]
        }
        return parsed
    }
    
    private func unwrapMCPEnvelope(_ raw: Any) -> Any {
        // JSON-RPC envelope → the tool's own JSON.
        // { jsonrpc, id, result: { content: [ { type: "text", text: "{...}" } ] } }
        
        var current = raw

        if let dict = current as? [String: Any] {
            if let err = dict["error"] {
                return ["error": err]
            }
            if let result = dict["result"] {
                current = result
            }
        }

        if let dict = current as? [String: Any] {
            // MCP tool-level failure flag
            if (dict["isError"] as? Bool) == true,
               let content = dict["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String {
                return ["error": text]
            }
            if let content = dict["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String {
                if let data = text.data(using: .utf8),
                   let parsed = try? JSONSerialization.jsonObject(with: data) {
                    return parsed
                }
                return ["text": text]   // non-JSON tool output, pass through
            }
        }

        return current
    }
}

extension MempalaceMemory {

    func overview(limit: Int?) async throws -> MemoryOverview {
        // Recents: bounded filed_at window, sorted newest-first
        // Widens if the recent window is quiet.

        var overview = MemoryOverview(status: nil, recents: [])

        let want = min(limit ?? 25, 100)
        for days in [14, 90, nil as Int?] {
            do {
                let since = days.map { Self.isoDate(daysAgo: $0) }
                let page = try await pageEntries(wing: nil, room: nil, limit: 100, offset: 0, since: since)
                if (!page.drawers.isEmpty) || (days == nil) {
                    overview.recents = page.drawers
                        .sorted { ($0.filedAt ?? "") > ($1.filedAt ?? "") }
                        .prefix(want)
                        .map { $0 }
                    break
                }
            } catch {
                overview.recentsError = "\(error)"
                break
            }
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
    
    func pageEntries(
        wing: String?,
        room: String?,
        limit: Int?,
        offset: Int?,
        since: String? = nil,
        before: String? = nil
    ) async throws -> MemoryDrawerPage {
        // Offset pagination (limit ≤ 100). Next page: offset + drawers.count; done when that reaches total.
        var args: [String: Any] = [
            "limit": min(limit ?? 25, 100),
            "offset": max(offset ?? 0, 0)
        ]
        if let wing { args["wing"] = wing }
        if let room { args["room"] = room }
        if let since { args["since"] = since }
        if let before { args["before"] = before }
        let raw = try await execStructured(name: "mempalace_list_drawers", args: args)
        return try MempalaceMemory.decode(MemoryDrawerPage.self, from: raw)
    }

    func searchStructured(
        query: String,
        wing: String?,
        room: String?,
        limit: Int?,
        context: String? = nil,
        maxDistance: Double? = nil,
        sourceFile: String? = nil
    ) async throws -> MemorySearchResults {
        var args: [String: Any] = ["query": String(query.prefix(250)), "limit": (limit ?? 8)]
        if let wing { args["wing"] = wing }
        if let room { args["room"] = room }
        if let context { args["context"] = context }
        if let maxDistance { args["max_distance"] = maxDistance }
        if let sourceFile { args["source_file"] = sourceFile }
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
    
    func resolveDrawerID(content: String, wing: String?, room: String?) async throws -> String {
        // Search results carry no drawer id — resolve one from verbatim content (via check_duplicate).
        // Matches are best-first
        let raw = try await execStructured(
            name: "mempalace_check_duplicate",
            args: ["content": content, "threshold": 0.98]
        )

        guard let dict = raw as? [String: Any] else {
            throw MemoryError.badResponse("unexpected check_duplicate response")
        }
        if (dict["vector_disabled"] as? Bool) == true {
            throw MemoryError.badResponse("duplicate detection unavailable (vector index disabled) — run `mempalace repair`")
        }
        guard let matches = dict["matches"] as? [[String: Any]],
              let best = matches.first,
              let id = best["id"] as? String else {
            throw MemoryError.badResponse("no matching drawer found for content delete")
        }

        // Never delete a near-twin filed elsewhere: if the caller knows the
        // drawer's location, the resolved match must agree.
        if let wing, let matchWing = best["wing"] as? String, (matchWing != wing) {
            throw MemoryError.badResponse("resolved drawer is in a different wing (\(matchWing)) — not deleting")
        }
        if let room, let matchRoom = best["room"] as? String, (matchRoom != room) {
            throw MemoryError.badResponse("resolved drawer is in a different room (\(matchRoom)) — not deleting")
        }

        return id
    }
}

extension MempalaceMemory {

    static func isoDate(daysAgo: Int) -> String {
        let date = Date().addingTimeInterval(-Double(daysAgo) * 86_400)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date) // "YYYY-MM-DD", matches the schema's example
    }
    
    static func decode<T: Decodable>(_ type: T.Type, from any: Any) throws -> T {
        if let dict = any as? [String: Any], let err = dict["error"] {
            throw MemoryError.badResponse("tool error: \(err)")
        }
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
    
    static func stringify(_ value: Any) -> String {
        if let s = value as? String { return s }
        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value),
           let s = String(data: data, encoding: .utf8) {
            return s
        }
        return String(describing: value)
    }
}

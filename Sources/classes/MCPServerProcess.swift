//
//  MCPServerProcess.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/6/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

actor MCPServerProcess {
    
    private let name: String
    private let executable: String
    private let arguments: [String]
    private let environment: [String: String]
    private let requestTimeout: TimeInterval

    private var process: Process?
    private var stdinHandle: FileHandle?
    private var initialized = false
    private var nextID = 1
    private var pending: [Int: CheckedContinuation<String, Error>] = [:]
    private var generation = 0   // bumped per launch; events from dead instances ignored

    init(
        name: String,
        executable: String,
        arguments: [String],
        environment: [String: String],
        requestTimeout: TimeInterval = 60
    ) {
        self.name = name
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
        self.requestTimeout = requestTimeout
    }

    func callTool(name toolName: String, argumentsData: Data, timeout: TimeInterval? = nil) async throws -> String {
        // Tool call → raw JSON-RPC response line (parse caller-side)
        guard let arguments = (try? JSONSerialization.jsonObject(with: argumentsData)) as? [String: Any] else {
            throw MCPProcessError.badResponse("arguments were not a JSON object")
        }
        return try await request(
            method: "tools/call",
            params: ["name": toolName, "arguments": arguments],
            timeout: timeout ?? requestTimeout
        )
    }

    func listTools() async throws -> String {
        // Tool discovery — ground truth for what the running server supports.
        try await request(method: "tools/list", params: [:], timeout: requestTimeout)
    }

    func shutdown() {
        let p = process
        process = nil
        stdinHandle = nil
        initialized = false
        failAllPending(MCPProcessError.notRunning)
        p?.terminate()
    }

    private func request(method: String, params: [String: Any], timeout: TimeInterval) async throws -> String {
        try ensureRunning()
        if (!initialized) { try await handshake() }
        return try await rawRequest(method: method, params: params, timeout: timeout)
    }

    private func rawRequest(method: String, params: [String: Any], timeout: TimeInterval) async throws -> String {
        let id = nextID
        nextID += 1

        return try await withCheckedThrowingContinuation { cont in
            pending[id] = cont
            do {
                try send(["jsonrpc": "2.0", "id": id, "method": method, "params": params])
            } catch {
                pending.removeValue(forKey: id)
                cont.resume(throwing: error)
                return
            }
            // Timeout watchdog for this id.
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                await self?.timeOut(id: id, method: method, after: timeout)
            }
        }
    }

    private func timeOut(id: Int, method: String, after: TimeInterval) {
        if let cont = pending.removeValue(forKey: id) {
            cont.resume(throwing: MCPProcessError.timeout("\(name).\(method) after \(Int(after))s"))
        }
    }

    private func fulfill(id: Int, raw: String, generation gen: Int) {
        guard (gen == generation) else { return }   // line from a dead instance
        pending.removeValue(forKey: id)?.resume(returning: raw)
    }

    private func processDied(generation gen: Int) {
        guard (gen == generation),
              (process != nil) else { return }
        print("MCP [\(name)] exited.")
        process = nil
        stdinHandle = nil
        initialized = false
        failAllPending(MCPProcessError.badResponse("\(name) exited mid-request"))
    }

    private func failAllPending(_ error: Error) {
        let waiting = pending
        pending.removeAll()
        for (_, cont) in waiting {
            cont.resume(throwing: error)
        }
    }

    private func ensureRunning() throws {
        if (process?.isRunning == true) { return }

        generation += 1
        let gen = generation
        initialized = false

        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = arguments
        p.environment = environment

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        p.standardInput = stdinPipe
        p.standardOutput = stdoutPipe
        p.standardError = FileHandle.standardError   // server logs pass through to console

        p.terminationHandler = { [weak self] _ in
            Task {
                await self?.processDied(generation: gen)
            }
        }

        do {
            try p.run()
        } catch {
            throw MCPProcessError.launchFailed("\(name): \(error)")
        }

        process = p
        stdinHandle = stdinPipe.fileHandleForWriting
        startReader(stdoutPipe.fileHandleForReading, generation: gen)

        print("MCP [\(name)] launched (pid \(p.processIdentifier)), initializing…")
    }

    private func handshake() async throws {
        // First launch imports chromadb — be generous.
        let raw = try await rawRequest(
            method: "initialize",
            params: [
                "protocolVersion": "2025-06-18",
                "capabilities": [String: Any](),
                "clientInfo": ["name": "DAWSON", "version": "1.0"]
            ],
            timeout: 120
        )
        if let data = raw.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = dict["error"] {
            throw MCPProcessError.badResponse("\(name) initialize error: \(error)")
        }
        try send(["jsonrpc": "2.0", "method": "notifications/initialized"])
        initialized = true
        print("MCP [\(name)] ready.")
    }

    private func send(_ message: [String: Any]) throws {
        guard let stdinHandle,
              (process?.isRunning == true) else {
            throw MCPProcessError.notRunning
        }
        var data = try JSONSerialization.data(withJSONObject: message)
        data.append(0x0A)   // newline delimiter
        stdinHandle.write(data)
    }

    private nonisolated func startReader(_ handle: FileHandle, generation gen: Int) {
        // Reader (nonisolated thread; thread-local buffering)
        Thread.detachNewThread { [weak self] in
            var buffer = Data()
            while true {
                let chunk = handle.availableData
                if chunk.isEmpty { break }               // EOF — process exited
                buffer.append(chunk)

                while let newline = buffer.firstIndex(of: 0x0A) {
                    let line = buffer.subdata(in: buffer.startIndex..<newline)
                    buffer.removeSubrange(buffer.startIndex...newline)
                    guard (!line.isEmpty),
                          let raw = String(data: line, encoding: .utf8),
                          let parsed = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                          let id = parsed["id"] as? Int else {
                        continue   // stdout noise or id-less notification: ignore
                    }
                    Task { await self?.fulfill(id: id, raw: raw, generation: gen) }
                }
            }
            // EOF: termination handler performs the actual cleanup; this is
            // a belt-and-suspenders wake in case the handler doesn't fire.
            Task { await self?.processDied(generation: gen) }
        }
    }
}

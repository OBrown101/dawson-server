//
//  MCPServersConfig.swift
//  DAWSON
//
//  Created by Ethan Brown on 11/4/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import MCP
import System

struct MCPServerConfig: Codable {
    let name: String
    let executablePath: String
    let args: [String]?
    let trusted: Bool?              // true: call_tool flows without per-call approval (Warrior)
    let blockedTools: [String]?     // refused below Ultimate regardless of trust
}

struct ConfigFile: Codable {
    let servers: [MCPServerConfig]
}

final class MCPServersConfig: @unchecked Sendable {
    static let shared = MCPServersConfig()

    static let configURL = DAWSON.databank.appendingPathComponent("mcp-servers.json")

    private(set) var servers: [String: MCPServerConfig] = [:]

    private init() {
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: Self.configURL) else {
            // no config file — no servers, nothing to do
            return
        }
        
        guard let parsed = try? JSONDecoder().decode(ConfigFile.self, from: data) else {
            print("MCP config: could not parse \(Self.configURL.path); no servers registered.")
            return
        }
        servers = Dictionary(parsed.servers.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func isTrusted(_ serverName: String) -> Bool {
        return servers[serverName]?.trusted ?? false
    }

    func blockedTools(_ serverName: String) -> Set<String> {
        return Set(servers[serverName]?.blockedTools ?? [])
    }

    func registerConfigured() async {
        // Launches/registers all configured servers.
        // Call once during server startup, after PythonHandler ready.
        for (_, cfg) in servers {
            do {
                try await MCPHandler.shared.registerServer(serverName: cfg.name) {
                    // Launch configured executable directly. MCP server
                    // processes are user-configured, DAWSON-launched
                    // (unsandboxed), same trust level as existing
                    // register path — which only supports Python scripts.
                    guard FileManager.default.isExecutableFile(atPath: cfg.executablePath) else {
                        throw MCPProcessError.launchFailed("\(cfg.name): '\(cfg.executablePath)' is not an executable file")
                    }

                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: cfg.executablePath)
                    process.arguments = cfg.args ?? []

                    // DAWSON's own process env carries PYTHONHOME/PYTHONPATH
                    // for bundled 3.11 (PythonEnv.setEnv in main.swift).
                    // Child with own interpreter (uvx-managed CPython)
                    // fatally mis-boots against that home — strip them.
                    var env = ProcessInfo.processInfo.environment
                    env.removeValue(forKey: "PYTHONHOME")
                    env.removeValue(forKey: "PYTHONPATH")
                    env.removeValue(forKey: "PYTHONSAFEPATH")
                    process.environment = env

                    let stdinPipe = Pipe()
                    let stdoutPipe = Pipe()
                    process.standardInput = stdinPipe
                    process.standardOutput = stdoutPipe
                    process.standardError = FileHandle.standardError // server logs -> DAWSON log

                    try process.run()

                    // StdioTransport: input = where we READ the server's
                    // stdout; output = where we WRITE to the server's stdin.
                    return StdioTransport(
                        input: FileDescriptor(rawValue: stdoutPipe.fileHandleForReading.fileDescriptor),
                        output: FileDescriptor(rawValue: stdinPipe.fileHandleForWriting.fileDescriptor)
                    )
                }
                print("MCP [\(cfg.name)] registered from mcp-servers.json.")
            } catch {
                print("MCP [\(cfg.name)] registration failed: \(error.localizedDescription)")
            }
        }
    }
}

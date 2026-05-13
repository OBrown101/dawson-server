//
//  MCPHandler.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/10/26.
//

import Foundation
import MCP

enum MCPHandlerError: LocalizedError {
    case clientAlreadyExists(String)
    case clientNotFound(String)
    case serverNotConnected(String)
    case toolNotFound(String)
    case invalidResponse
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .clientAlreadyExists(let name):
            return "An MCP client named '\(name)' already exists."
        case .clientNotFound(let name):
            return "No MCP client named '\(name)' exists."
        case .serverNotConnected(let name):
            return "MCP server '\(name)' is not connected."
        case .toolNotFound(let name):
            return "Tool '\(name)' was not found."
        case .invalidResponse:
            return "Received an invalid response from the MCP server."
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}

final class MCPHandler: @unchecked Sendable {
    static let shared = MCPHandler()
    
    private let queue = DispatchQueue(label: "mcp.handler.queue")
    private var servers: [String: MCPServer] = [:]

    private init() {}

    func registerServer(
        serverName: String,
        transport: @escaping @Sendable () async throws -> Transport
    ) async throws {
        if queue.sync(execute: { servers[serverName] != nil }) {
            throw MCPHandlerError.clientAlreadyExists(serverName)
        }

        do {
            let transport = try await transport()
            let client = Client(name: "DAWSON", version: "1.0.0")

            try await client.connect(transport: transport)

            let server = MCPServer(
                name: serverName,
                client: client,
                transport: transport
            )

            queue.sync {
                servers[serverName] = server
            }
        } catch {
            throw MCPHandlerError.underlying(error)
        }
    }

    func disconnectServer(serverName: String) async {
        queue.sync {
            if (servers.keys.contains(serverName)) {
                servers.removeValue(forKey: serverName)
            }
        }
    }

    func disconnectAllServers() async {
        queue.sync {
            for name in servers.keys {
                if (servers.keys.contains(name)) {
                    servers.removeValue(forKey: name)
                }
            }
        }
    }

    func isConnected(serverName: String) -> Bool {
        queue.sync {
            servers.keys.contains(serverName)
        }
    }

    func callTool(
        serverName: String,
        toolName: String,
        arguments: [String: Any] = [:]
    ) async throws -> [MCP.Tool.Content] {
        guard try await isToolAvailable(serverName: serverName, toolName: toolName) else {
            throw MCPHandlerError.toolNotFound(toolName)
        }
        
        guard let server = queue.sync(execute: { servers[serverName] }) else {
            throw MCPHandlerError.clientNotFound(serverName)
        }

        if (!isConnected(serverName: serverName)) {
            throw MCPHandlerError.serverNotConnected(serverName)
        }

        do {
            let result = try await server.client.callTool(
                name: toolName,
                arguments: arguments as? [String : Value]
            )
            return (result.isError ?? false) ? [] : result.content
        } catch {
            throw MCPHandlerError.underlying(error)
        }
    }
}

extension MCPHandler {
    func getAllServerNames() -> [String] {
        queue.sync {
            Array(servers.keys).sorted()
        }
    }

    func getAllTools(serverName: String) async throws -> [MCP.Tool] {
        guard let server = queue.sync(execute: { servers[serverName] }) else {
            throw MCPHandlerError.clientNotFound(serverName)
        }

        if (!isConnected(serverName: serverName)) {
            throw MCPHandlerError.serverNotConnected(serverName)
        }

        do {
            let result = try await server.client.listTools()
            return result.tools
        } catch {
            throw MCPHandlerError.underlying(error)
        }
    }

    func listToolNames(serverName: String) async throws -> [String] {
        let tools = try await getAllTools(serverName: serverName)
        return tools.map(\.name).sorted()
    }
    
    func isToolAvailable(serverName: String, toolName: String) async throws -> Bool {
        let names = try await listToolNames(serverName: serverName)
        return names.contains(toolName)
    }
    
    func convToString(_ content: [MCP.Tool.Content]) -> String {
        var parts: [String] = []

        for item in content {
            switch item {
            case .text(let textContent, _, _):
                parts.append(textContent)
            case .image(_, let mimeType, _, _):
                parts.append("[Image: \(mimeType)]")
            case .resource(let resource, _, _):
                parts.append("[Resource: \(resource.uri)]")
            default:
                parts.append(String(describing: item))
            }
        }

        return parts.joined(separator: "\n\n")
    }
}

//
//  MCPTool.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/11/26.
//

import Foundation
import MCP
import System

class MCPTool: PermissionAware {
    let name = "mcp_tool"
    
    func permissionRequests(args: [String : Any]) -> [PermissionRequest] {
        return [
            PermissionRequest(action: .all)
        ]
    }
    
    enum MCPAction: String, CaseIterable {
        case listServers = "list_servers"
        case listTools = "list_tools"
        case callTool = "call_tool"
        case registerServer = "register_server"
        
        var description: String {
            switch self {
            case .listServers:
                return "Return all connected MCP server names."
            case .listTools:
                return "Return all tools for a specified server."
            case .callTool:
                return "Invoke a tool on a specified server. This should match the schema expected by the target tool."
            case .registerServer:
                return """
                Register a new MCP server that runs as a local process.

                Arguments format:
                {
                    "executable_path": "/path/to/server.py",
                    "args": ["-m", "mcp_server", "--config", "/path/config.json"]
                }

                Example:
                {
                    "executable_path": "/Users/Jim/Dawson-Core/server.py",
                    "args": ["-m", "mempalace.mcp_server", "--palace", "/path/to/palace"]
                }
                """
            }
        }
    }
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": name,
            "description": """
            Interact with any connected Model Context Protocol (MCP) server.

            Use this tool to:
            - List all connected MCP servers
            - List all tools available on a specific MCP server
            - Call a tool on a specific MCP server with arguments
            - Register a new MCP server

            This allows the agent to dynamically use capabilities provided by
            external applications and services connected through MCP.
            """,
            "parameters": [
                "type": "object",
                "required": ["action"],
                "properties": [
                    "action": [
                        "type": "string",
                        "enum": [
                            MCPAction.listServers.rawValue,
                            MCPAction.listTools.rawValue,
                            MCPAction.callTool.rawValue,
                            MCPAction.registerServer.rawValue
                        ],
                        "description": """
                        The action to perform:
                        - \(MCPAction.listServers.rawValue): \(MCPAction.listServers.description)
                        - \(MCPAction.listTools.rawValue): \(MCPAction.listTools.description)
                        - \(MCPAction.callTool.rawValue): \(MCPAction.callTool.description)
                        - \(MCPAction.registerServer.rawValue): \(MCPAction.registerServer.description)
                        """
                    ],
                    "server_name": [
                        "type": "string",
                        "description": "The name of the MCP server."
                    ],
                    "tool_name": [
                        "type": "string",
                        "description": "The name of the tool to call."
                    ],
                    "arguments": [
                        "type": "object",
                        "description": "Arguments for given MCP tool call or other MCP control action.",
                        "additionalProperties": true
                    ]
                ]
            ]
        ]
    }
    
    func anthropicSchema() -> [String : Any] {
        return [
            "name": name,
            "description": """
            Interact with any connected Model Context Protocol (MCP) server.

            Use this tool to:
            - List all connected MCP servers
            - List all tools available on a specific MCP server
            - Call a tool on a specific MCP server with arguments
            - Register a new MCP server

            This allows the agent to dynamically use capabilities provided by
            external applications and services connected through MCP.
            """,
            "input_schema": [
                "type": "object",
                "required": ["action"],
                "properties": [
                    "action": [
                        "type": "string",
                        "enum": [
                            MCPAction.listServers.rawValue,
                            MCPAction.listTools.rawValue,
                            MCPAction.callTool.rawValue,
                            MCPAction.registerServer.rawValue
                        ],
                        "description": """
                        The action to perform:
                        - \(MCPAction.listServers.rawValue): \(MCPAction.listServers.description)
                        - \(MCPAction.listTools.rawValue): \(MCPAction.listTools.description)
                        - \(MCPAction.callTool.rawValue): \(MCPAction.callTool.description)
                        - \(MCPAction.registerServer.rawValue): \(MCPAction.registerServer.description)
                        """
                    ],
                    "server_name": [
                        "type": "string",
                        "description": "The name of the MCP server."
                    ],
                    "tool_name": [
                        "type": "string",
                        "description": "The name of the tool to call."
                    ],
                    "arguments": [
                        "type": "object",
                        "description": "Arguments for given MCP tool call or other MCP control action.",
                        "additionalProperties": true
                    ]
                ]
            ]
        ]
    }
    
    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": """
                Interact with any connected Model Context Protocol (MCP) server.

                Use this tool to:
                - List all connected MCP servers
                - List all tools available on a specific MCP server
                - Call a tool on a specific MCP server with arguments
                - Register a new MCP server

                This allows the agent to dynamically use capabilities provided by
                external applications and services connected through MCP.
                """,
                "parameters": [
                    "type": "object",
                    "required": ["action"],
                    "properties": [
                        "action": [
                            "type": "string",
                            "enum": [
                                "\(MCPAction.listServers)",
                                "\(MCPAction.listTools)",
                                "\(MCPAction.callTool)",
                                "\(MCPAction.registerServer)"
                            ],
                            "description": """
                            The action to perform:
                            - \(MCPAction.listServers): \(MCPAction.listServers.description)
                            - \(MCPAction.listTools): \(MCPAction.listTools.description)
                            - \(MCPAction.callTool): \(MCPAction.callTool.description)
                            - \(MCPAction.registerServer): \(MCPAction.registerServer.description)
                            """
                        ],
                        "server_name": [
                            "type": "string",
                            "description": "The name of the MCP server."
                        ],
                        "tool_name": [
                            "type": "string",
                            "description": "The name of the tool to call."
                        ],
                        "arguments": [
                            "type": "object",
                            "description": "Arguments for given MCP tool call or other MCP control action.",
                            "additionalProperties": true
                        ]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let action = args["action"] as? String else {
            return "Error: Missing required parameter 'action'."
        }
        
        let mcpAction = MCPAction(rawValue: action)
        switch (mcpAction) {
        case .listServers:
            return await listServers(args)
        case .listTools:
            return await listTools(args)
        case .callTool:
            return await callTool(args)
        case .registerServer:
            return await registerServer(args)
        default:
            return """
            Error: Invalid action '\(action)'.
            Valid actions: \(MCPAction.allCases.map { "\n- \($0.rawValue)"})
            """
        }
    }
    
    private func listServers(_ args: [String: Any]) async -> String {
        let servers = MCPHandler.shared.getAllServerNames()
        if (servers.isEmpty) {
            return "No MCP servers are currently connected."
        }
        return servers.joined(separator: "\n")
    }
    
    private func listTools(_ args: [String: Any]) async -> String {
        guard let serverName = args["server_name"] as? String,
              (!serverName.isEmpty) else {
            return "Error: 'server_name' is required for action '\(MCPAction.listTools)'."
        }
        
        do {
            let toolNames = try await MCPHandler.shared.listToolNames(serverName: serverName)
            if (toolNames.isEmpty) {
                return "No tools are available on MCP server '\(serverName)'."
            }

            return toolNames.joined(separator: "\n")
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    private func callTool(_ args: [String: Any]) async -> String {
        guard let serverName = args["server_name"] as? String,
              (!serverName.isEmpty) else {
            return "Error: 'server_name' is required for action '\(MCPAction.callTool)'."
        }

        guard let toolName = args["tool_name"] as? String,
              (!toolName.isEmpty) else {
            return "Error: 'tool_name' is required for action 'call_tool'."
        }

        let toolArguments = args["arguments"] as? [String: Any] ?? [:]

        do {
            let content = try await MCPHandler.shared.callTool(
                serverName: serverName,
                toolName: toolName,
                arguments: toolArguments
            )

            if (content.isEmpty) {
                return "The tool '\(toolName)' completed successfully but returned no content."
            }

            return MCPHandler.shared.convToString(content)
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    private func registerServer(_ args: [String: Any]) async -> String {
        guard let serverName = args["server_name"] as? String,
              (!serverName.isEmpty) else {
            return "Error: 'server_name' is required for action '\(MCPAction.registerServer)'."
        }

        guard let registerArgs = args["arguments"] as? [String: Any] else {
            return "Error: 'arguments' is required for action 'register_mcp'."
        }

        guard let executablePath = registerArgs["executable_path"] as? String,
              (!executablePath.isEmpty) else {
            return "Error: 'arguments.executable_path' is required."
        }

        let processArgs = registerArgs["args"] as? [String] ?? []

        do {
            try await MCPHandler.shared.registerServer(serverName: serverName) {
                let inputPipe = Pipe()
                let outputPipe = Pipe()
                let errorPipe = Pipe()

                _ = try PythonHandler.shared.startPythonProcess(
                    scriptPath: executablePath,
                    arguments: processArgs,
                    inputPipe: inputPipe,
                    outputPipe: outputPipe,
                    errorPipe: errorPipe
                )

                return StdioTransport(
                    input: FileDescriptor(rawValue: inputPipe.fileHandleForReading.fileDescriptor),
                    output: FileDescriptor(rawValue: outputPipe.fileHandleForWriting.fileDescriptor)
                )
            }

            let tools = try await MCPHandler.shared.listToolNames(serverName: serverName)

            return """
            MCP server '\(serverName)' registered successfully.
            Executable: \(executablePath)
            Tools:
            \(tools.isEmpty ? "No tools exposed" : tools.map { "- \($0)" }.joined(separator: "\n"))
            """
        } catch {
            return "Error registering MCP server: \(error.localizedDescription)"
        }
    }
}

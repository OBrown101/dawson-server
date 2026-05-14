//
//  MempalaceTool.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/12/26.
//

import Foundation

class MempalaceTool: Tool {
    let name = "mempalace"

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": """
                Interface to the Mempalace MCP memory system.
                Used for storing, retrieving, and searching long-term memory, conversation history, and semantic context.
                
                This tool routes requests to a Mempalace MCP server that is already setup. DO NOT register this server, it is already setup and running.
                """,
                "parameters": [
                    "type": "object",
                    "required": ["action"],
                    "properties": [
                        "action": [
                            "type": "string",
                            "description": """
                            The Mempalace operation to perform.
                            Examples: mempalace_add_drawer, mempalace_search, mempalace_status
                            """
                        ],
                        "args": [
                            "type": "object",
                            "description": "Arguments forwarded directly to the Mempalace MCP tool",
                            "additionalProperties": true
                        ]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let action = args["action"] as? String, !action.isEmpty else {
            return "Error: No action provided."
        }

        let rawArgs = args["args"] as? [String: Any] ?? [:]

        do {
            let content = try await MCPHandler.shared.callTool(
                serverName: "mempalace",
                toolName: action,
                arguments: rawArgs
            )

            return MCPHandler.shared.convToString(content)
        } catch {
            return "Mempalace error (\(action)): \(error)"
        }
    }
}

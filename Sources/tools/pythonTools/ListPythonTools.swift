//
//  ListPythonTools.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/21/26.
//

import Foundation

class ListPythonTools: PermissionAware {
    static let name = "list_python_tools"
    
    func permissionRequests(args: [String: Any]) -> [PermissionRequest] {
        return [PermissionRequest(action: .read)]
    }

    private let toolDescription = """
        Lists every tool in DAWSON's shared Python library: module names, \
        descriptions, and public functions with their signatures. ALWAYS call \
        this before writing a new Python tool — if a suitable tool already \
        exists, use it via \(RunPythonScript.name) instead of rewriting it. Takes no \
        parameters and is instant.
        """

    private let parameterSchema: [String: Any] = [
        "type": "object",
        "properties": [:] as [String: Any]
    ]

    func openAISchema() -> [String: Any] {
        return [
            "type": "function",
            "name": ListPythonTools.name,
            "description": toolDescription,
            "parameters": parameterSchema
        ]
    }

    func anthropicSchema() -> [String: Any] {
        return [
            "name": ListPythonTools.name,
            "description": toolDescription,
            "input_schema": parameterSchema
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": ListPythonTools.name,
                "description": toolDescription,
                "parameters": parameterSchema
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        return await Task.detached(priority: .utility) {
            ToolCatalog.formattedList()
        }.value
    }
}

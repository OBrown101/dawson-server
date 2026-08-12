//
//  RichFormatter.swift
//  DAWSON
//
//  Created by Ethan Brown on 3/31/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

class RichFormatter: Tool {
    static let name = "rich_formatter"
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": RichFormatter.name,
            "description": "Formats text using Markdown, adds code blocks or tables.",
            "parameters": [
                "type": "object",
                "required": ["text", "format"],
                "properties": [
                    "text": [
                        "type": "string",
                        "description": "Text to format"
                    ],
                    "format": [
                        "type": "string",
                        "description": "Format type: markdown, code, table"
                    ]
                ]
            ]
        ]
    }
    
    func anthropicSchema() -> [String : Any] {
        return [
            "name": RichFormatter.name,
            "description": "Formats text using Markdown, adds code blocks or tables.",
            "input_schema": [
                "type": "object",
                "required": ["text", "format"],
                "properties": [
                    "text": [
                        "type": "string",
                        "description": "Text to format"
                    ],
                    "format": [
                        "type": "string",
                        "description": "Format type: markdown, code, table"
                    ]
                ]
            ]
        ]
    }
    
    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": RichFormatter.name,
                "description": "Formats text using Markdown, adds code blocks or tables.",
                "parameters": [
                    "type": "object",
                    "required": ["text", "format"],
                    "properties": [
                        "text": [
                            "type": "string",
                            "description": "Text to format"
                        ],
                        "format": [
                            "type": "string",
                            "description": "Format type: markdown, code, table"
                        ]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let text = args["text"] as? String,
              let format = args["format"] as? String else {
            return "Error: Missing text or format."
        }

        switch format.lowercased() {
        case "markdown":
            return "**Markdown:** \(text)"
        case "code":
            return "```\n\(text)\n```"
        case "table":
            let rows = text.components(separatedBy: "\n")
            let formattedRows = rows.map { "| \($0.replacingOccurrences(of: ",", with: " | ")) |" }
            return formattedRows.joined(separator: "\n")
        default:
            return text
        }
    }
}

//
//  RichFormatter.swift
//  
//
//  Created by Ethan Brown on 3/31/26.
//

import Foundation

class RichFormatter: Tool {
    let name = "rich_formatter"

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
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

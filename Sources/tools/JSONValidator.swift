//
//  JSONValidator.swift
//
//  Created by Ethan Brown on 3/23/26.
//

import Foundation

class JSONValidator: Tool {
    let name = "validate_json"

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Validates a JSON string and returns a formatted version or an error",
                "parameters": [
                    "type": "object",
                    "required": ["jsonString"],
                    "properties": [
                        "jsonString": [
                            "type": "string",
                            "description": "The JSON string to validate"
                        ]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) -> String {
        guard let jsonString = args["jsonString"] as? String,
              let data = jsonString.data(using: .utf8) else {
            return "Error: Invalid JSON string."
        }

        do {
            let object = try JSONSerialization.jsonObject(with: data)
            let prettyData = try JSONSerialization.data(withJSONObject: object, options: .prettyPrinted)
            return String(data: prettyData, encoding: .utf8) ?? "Error formatting JSON."
        } catch {
            return "Invalid JSON: \(error.localizedDescription)"
        }
    }
}

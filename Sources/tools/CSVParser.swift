//
//  CSVParser.swift
//
//  Created by Ethan Brown on 3/23/26.
//

import Foundation

class CSVParser: Tool {
    let name = "parse_csv"

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Parses a CSV file and returns its content as JSON",
                "parameters": [
                    "type": "object",
                    "required": ["path"],
                    "properties": [
                        "path": [
                            "type": "string",
                            "description": "Path to the CSV file"
                        ],
                        "delimiter": [
                            "type": "string",
                            "description": "Optional delimiter (default is ,)"
                        ]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) -> String {
        guard let path = args["path"] as? String else {
            return "Error: CSV path not provided."
        }

        let delimiter = (args["delimiter"] as? String) ?? ","
        do {
            let content = try String(contentsOfFile: path)
            let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
            guard let headerLine = lines.first else { return "CSV is empty." }
            let headers = headerLine.components(separatedBy: delimiter)
            var result: [[String: String]] = []

            for line in lines.dropFirst() {
                let values = line.components(separatedBy: delimiter)
                var row: [String: String] = [:]
                for (i, header) in headers.enumerated() {
                    if i < values.count {
                        row[header] = values[i]
                    }
                }
                result.append(row)
            }

            let jsonData = try JSONSerialization.data(withJSONObject: result, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "Error encoding JSON"
        } catch {
            return "Error reading CSV: \(error.localizedDescription)"
        }
    }
}

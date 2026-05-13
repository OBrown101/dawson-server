//
//  TextSearch.swift
//
//  Created by Ethan Brown on 3/23/26.
//

import Foundation

class TextSearch: Tool {
    let name = "text_search"

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Searches for a text pattern in a file or directory recursively",
                "parameters": [
                    "type": "object",
                    "required": ["pattern", "path"],
                    "properties": [
                        "pattern": [
                            "type": "string",
                            "description": "Text pattern to search for"
                        ],
                        "path": [
                            "type": "string",
                            "description": "File or directory path to search"
                        ]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let pattern = args["pattern"] as? String,
              let path = args["path"] as? String else {
            return "Error: Missing pattern or path."
        }

        var results: [String] = []

        func searchFile(_ filePath: String) {
            if let content = try? String(contentsOfFile: filePath) {
                let lines = content.components(separatedBy: "\n")
                for (index, line) in lines.enumerated() {
                    if line.contains(pattern) {
                        results.append("\(filePath):\(index+1): \(line)")
                    }
                }
            }
        }

        let fm = FileManager.default
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: path, isDirectory: &isDir) {
//            if isDir.boolValue {
//                if let enumerator = fm.enumerator(atPath: path) {
//                    for case let file as String in enumerator {
//                        searchFile((path as NSString).appendingPathComponent(file))
//                    }
//                }
//            } else {
//                searchFile(path)
//            }
        } else {
            return "Error: Path does not exist."
        }

        return results.joined(separator: "\n")
    }
}

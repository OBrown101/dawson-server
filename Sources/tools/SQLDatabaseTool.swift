//
//  DatabaseTool.swift
//  
//
//  Created by Ethan Brown on 3/31/26.
//

import Foundation
import SQLite3

class SQLDatabaseTool: Tool {
    let name = "sql_database_tool"

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Executes SQL queries on a SQLite database.",
                "parameters": [
                    "type": "object",
                    "required": ["dbPath", "query"],
                    "properties": [
                        "dbPath": ["type": "string", "description": "Path to SQLite database file"],
                        "query": ["type": "string", "description": "SQL query to execute"]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) -> String {
        guard let dbPath = args["dbPath"] as? String,
              let query = args["query"] as? String else {
            return "Error: Missing dbPath or query."
        }

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            return "Error opening database."
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return "Error preparing query."
        }
        defer { sqlite3_finalize(stmt) }

        var results: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String] = []
            for i in 0..<sqlite3_column_count(stmt) {
                if let cStr = sqlite3_column_text(stmt, i) {
                    row.append(String(cString: cStr))
                } else {
                    row.append("NULL")
                }
            }
            results.append(row.joined(separator: ", "))
        }
        return results.isEmpty ? "No results." : results.joined(separator: "\n")
    }
}

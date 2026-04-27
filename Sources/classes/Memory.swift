//
//  Memory.swift
//
//
//  Created by Ethan Brown on 4/24/26.
//

import Foundation

final class Memory {

    private let handler: PythonHandler?
    
    private let defaultPalacePath = "~/.mempalace/palace"

    init() {
        do {
            handler = try PythonHandler(script: "pythonHandlers/mempalace_handler.py")
        } catch {
            handler = nil
            print("Could not initialise PythonHandler: \(error.localizedDescription)")
        }
        
        print(String(describing: getStatus()))
    }

    func getStatus() -> String? {
        guard let handler else {
            print("Python handler unavailable.")
            return nil
        }
        
        do {
            guard let wakeup = try handler.call(method: "status", params: [:]) else { return nil }
            return (wakeup["text"] as? String)
        } catch {
            print("Status getting failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    func getWakeUp() -> String? {
        guard let handler else {
            print("Python handler unavailable.")
            return nil
        }
        
        do {
            guard let wakeup = try handler.call(method: "wake_up", params: [:]) else { return nil }
            return (wakeup["text"] as? String)
        } catch {
            print("Wakeup getting failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    func search(query: String, wing: String? = nil, room: String? = nil, nResults: Int? = nil) -> [String: Any]? {
        guard let handler else {
            print("Python handler unavailable.")
            return nil
        }

        var params: [String: Any] = [
            "params": [
                "query": query,
                "palace_path": defaultPalacePath
            ]
        ]

        if let nResults {
            params["n_results"] = nResults
        }
        if let wing {
            params["wing"] = wing
        }
        if let room {
            params["room"] = room
        }

        do {
            guard let result = try handler.call(method: "search_memories", params: params),
                  (result["error"] == nil) else { return nil }
            return result
        } catch {
            print("Memory search failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    func getContext(prompt: String) -> String? {
        guard let searchResult = search(query: prompt),
              let results = searchResult["results"] as? [[String: Any]] else { return nil }
        
        let formatted = results.compactMap { r -> String? in
            guard let wing = r["wing"] as? String,
                  let room = r["room"] as? String,
                  let text = r["text"] as? String else {
                return nil
            }
            return "[\(wing)/\(room)] \(text)"
        }

        return formatted.joined(separator: "\n")
    }
}

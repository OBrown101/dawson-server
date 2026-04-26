//
//  Memory.swift
//
//
//  Created by Ethan Brown on 4/24/26.
//

import Foundation

class Memory {
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?

    init(pythonPath: String = "python/venv/bin/python3") {
        startProcess(pythonPath: pythonPath)
    }

    private func startProcess(pythonPath: String) {
        process = Process()
        inputPipe = Pipe()
        outputPipe = Pipe()

        process?.executableURL = URL(fileURLWithPath: pythonPath)
        process?.arguments = ["mempalace/mempalace_wrapper.py"]

        process?.standardInput = inputPipe
        process?.standardOutput = outputPipe

        do {
            try process?.run()
        } catch {
            print("Failed to start memory process:", error)
        }
    }

    private func send(_ payload: [String: Any]) async -> [String: Any]? {
        guard let input = inputPipe,
              let output = outputPipe else { return nil }

        do {
            let data = try JSONSerialization.data(withJSONObject: payload)
            if let jsonString = String(data: data, encoding: .utf8) {
                input.fileHandleForWriting.write((jsonString + "\n").data(using: .utf8)!)
            }

            let responseData = try output.fileHandleForReading.read(upToCount: 4096)
            guard let responseData = responseData,
                  let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
                return nil
            }

            return json
        } catch {
            print("MemoryBridge error:", error)
            return nil
        }
    }

    func getContext(query: String) async -> [Message] {
        let payload: [String: Any] = [
            "action": "get_context",
            "query": query
        ]

        guard let response = await send(payload),
              let messages = response["messages"] as? [[String: String]] else {
            return []
        }

        return messages.map {
            Message(role: $0["role"] ?? "system",
                    text: $0["content"] ?? "")
        }
    }

    func store(text: String) async {
        let payload: [String: Any] = [
            "action": "store",
            "text": text
        ]

        _ = await send(payload)
    }
}

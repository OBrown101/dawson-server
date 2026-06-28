//
//  AgentTaskRegistry.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/24/26.
//

import Foundation

actor AgentRunRegistry {
    static let shared = AgentRunRegistry()

    private var tasksByRunUUID: [String: Task<[Message], Error>] = [:]
    private var runUUIDByAgentUUID: [String: String] = [:]
    private var agentUUIDByRunUUID: [String: String] = [:]

    func register(runUUID: String, agentUUID: String, task: Task<[Message], Error>) {
        if let existingRunUUID = runUUIDByAgentUUID[agentUUID] {
            tasksByRunUUID[existingRunUUID]?.cancel()
            tasksByRunUUID.removeValue(forKey: existingRunUUID)
            agentUUIDByRunUUID.removeValue(forKey: existingRunUUID)
        }

        tasksByRunUUID[runUUID] = task
        runUUIDByAgentUUID[agentUUID] = runUUID
        agentUUIDByRunUUID[runUUID] = agentUUID
    }

    func remove(runUUID: String) {
        tasksByRunUUID.removeValue(forKey: runUUID)

        if let agentUUID = agentUUIDByRunUUID.removeValue(forKey: runUUID),
           runUUIDByAgentUUID[agentUUID] == runUUID {
            runUUIDByAgentUUID.removeValue(forKey: agentUUID)
        }
    }

    func cancel(runUUID: String) {
        tasksByRunUUID[runUUID]?.cancel()
        remove(runUUID: runUUID)
    }

    func cancelAgentRun(agentUUID: String) {
        guard let runUUID = runUUIDByAgentUUID[agentUUID] else { return }

        tasksByRunUUID[runUUID]?.cancel()
        remove(runUUID: runUUID)
        print("Agent (\(agentUUID)) run cancelled.")
    }

    func cancelAll() {
        for task in tasksByRunUUID.values {
            task.cancel()
        }

        tasksByRunUUID.removeAll()
        runUUIDByAgentUUID.removeAll()
        agentUUIDByRunUUID.removeAll()
    }
}

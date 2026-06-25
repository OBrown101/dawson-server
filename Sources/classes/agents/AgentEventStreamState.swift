//
//  AgentEventStreamState.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/24/26.
//

import Foundation

actor AgentEventStreamState {
    private var dataIndex: [String: Int32] = [:]
    private var currentRunUUID: String? = nil

    func getIndex(for key: String) -> Int32 {
        return dataIndex[key] ?? 0
    }
    
    func incrIndex(for key: String) {
        let index = dataIndex[key] ?? 0
        dataIndex[key] = (index + 1)
    }

    func setCurrentRunUUID(_ runUUID: String?) {
        currentRunUUID = runUUID
    }

    func finalState() -> (runUUID: String, lastDataIndex: Int32)? {
        guard let currentRunUUID else { return nil }

        let lastDataIndex = (dataIndex[AgentEvent.content().key] ?? 1) - 1
        return (currentRunUUID, lastDataIndex)
    }
}

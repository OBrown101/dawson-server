//
//  SuspensionRecord.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/29/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

struct AgentSuspensionRecord: Codable {
    var suspendData: Agent.SuspendData
    var toolBubbles: [String: PendingChildSuspension] = [:] // Pending child-suspension state held by delegation tools  (toolName key)
}

extension AgentSuspensionRecord {
    
    static let suspensionDirectory = Agent.agentsDirectory
        .appendingPathComponent("suspensions")

    static func loadMetadata(agentUUID: String) -> AgentSuspensionRecord? {
        let fileURL = metadataURL(agentUUID: agentUUID)
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(AgentSuspensionRecord.self, from: data)
        } catch {
            // If record no longer decodes (e.g. after a schema change) clear to prevent forever suspension
            print("Discarding undecodable suspension record for Agent \(agentUUID): ", error)
            deleteMetadata(agentUUID: agentUUID)
            return nil
        }
    }
    
    func saveMetadata(agentUUID: String) {
        do {
            try FileManager.default.createDirectory(at: AgentSuspensionRecord.suspensionDirectory, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(self)
            try data.write(to: AgentSuspensionRecord.metadataURL(agentUUID: agentUUID), options: .atomic)
        } catch {
            print("Failed to persist suspension for Agent \(agentUUID): ", error)
        }
    }

    static func deleteMetadata(agentUUID: String) {
        let fileURL = metadataURL(agentUUID: agentUUID)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    static func metadataURL(agentUUID: String) -> URL {
        return suspensionDirectory.appendingPathComponent("\(agentUUID).json")
    }
}

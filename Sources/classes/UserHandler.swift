//
//  UserHandler.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/1/26.
//

import Foundation

class UserHandler: @unchecked Sendable {
    static let shared = UserHandler()
    
    private var activeUsers: [String: User] = [:]
    
    
    init() {
        let savedUsers = User.loadAllUsers()
        activeUsers = Dictionary(uniqueKeysWithValues: savedUsers.map { ($0.uuid, $0) })
        print("Loaded Users: \(savedUsers)")
    }
    
    func upsertUser(_ user: User) {
        if (!activeUsers.keys.contains(user.uuid)) {
            createUser(user)
        } else {
            updateUser(user)
        }
        print("User (\(user.uuid) upserted.")
    }
    
    func deleteUser(_ userUUID: String) {
        activeUsers[userUUID]?.deleteMetadata()
        DAWSON.shared.deleteChatsForUser(userUUID)
        AgentHandler.shared.deleteAgentsForUser(userUUID)
        activeUsers.removeValue(forKey: userUUID)
        print("User (\(userUUID) deleted.")
        // TODO: Notification to sync user devices
    }
}

extension UserHandler {
    func createUser(_ user: User) {
        activeUsers[user.uuid] = user
        activeUsers[user.uuid]?.saveMetadata()
    }
    
    func updateUser(_ user: User) {
        activeUsers[user.uuid]?.name = user.name
        activeUsers[user.uuid]?.notes = user.notes
        activeUsers[user.uuid]?.updatedTimestamp = Int64(Date.now.timeIntervalSince1970)
        activeUsers[user.uuid]?.saveMetadata()
    }
}

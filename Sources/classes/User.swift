//
//  User.swift
//
//
//  Created by Ethan Brown on 3/22/26.
//

import Foundation

class User: Codable {
    let uuid: String
    var name: String
    var notes: [String] = []     // Short notes Dawson makes about the user (e.g. hobbies, personality)
    var updatedTimestamp: Int64
    
    static let usersDirectory = (DAWSON.workspace).appendingPathComponent("users")
    
    init(uuid: String, name: String, notes: [String] = [], updatedTimestamp: Int64 = Int64(Date.now.timeIntervalSince1970)) {
        self.uuid = uuid
        self.name = name
        self.notes = notes
        self.updatedTimestamp = updatedTimestamp
    }
}

extension User {
    static func loadAllUsers() -> [User] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: usersDirectory, includingPropertiesForKeys: nil) else { return [] }

        var users: [User] = []
        for fileURL in files {
            guard (fileURL.pathExtension == "json"),
                  let data = try? Data(contentsOf: fileURL),
                  let user = try? JSONDecoder().decode(User.self, from: data) else { continue }
            
            users.append(user)
        }
        return users
    }
    
    static func loadUser(userUUID: String) -> User? {
        let url = metadataURL(userUUID: userUUID)
        guard let data = try? Data(contentsOf: url),
              let user = try? JSONDecoder().decode(User.self, from: data) else { return nil }
        
        return user
    }
    
    func saveMetadata() {
        do {
            try FileManager.default.createDirectory(at: User.usersDirectory, withIntermediateDirectories: true)
            
            let data = try JSONEncoder().encode(self)
            try data.write(to: User.metadataURL(userUUID: uuid), options: .atomic)
            print("Successfully saved User \(uuid) metadata")
        } catch {
            print("Failed to save User \(uuid) metadata: ", error)
        }
    }
    
    func deleteMetadata() {
        let url = User.metadataURL(userUUID: uuid)

        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                print("Successfully deleted User \(uuid) metadata")
            } else {
                print("Metadata file for User \(uuid) not found")
            }
        } catch {
            print("Failed to delete User \(uuid) metadata: ", error)
        }
    }
    
    private static func metadataURL(userUUID: String) -> URL {
        return User.usersDirectory.appendingPathComponent("metadata_\(userUUID).json")
    }
}


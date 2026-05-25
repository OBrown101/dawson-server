//
//  User.swift
//
//
//  Created by Ethan Brown on 3/22/26.
//

import Foundation

class User: Codable {
    let uuid: String
    let name: String
    var notes: [String] = []     // Short notes Dawson makes about the user (e.g. hobbies, personality)
    
    private static let basePath = "/workspace/users"
    
    init(uuid: String, name: String, notes: [String] = []) {
        self.uuid = uuid
        self.name = name
        self.notes = notes
    }
}

extension User {
    private static func getProfilePath(for uuid: String) -> String {
        return (basePath as NSString).appendingPathComponent("\(uuid).json")
    }
    
    static func load(for uuid: String) -> User? {
        let path = getProfilePath(for: uuid)
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        
        return try? JSONDecoder().decode(User.self, from: data)
    }
    
    static func save(_ user: User) {
        let path = getProfilePath(for: user.uuid)
        let dir = (path as NSString).deletingLastPathComponent
        
        try? FileManager.default.createDirectory(
            atPath: dir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        if let data = try? JSONEncoder().encode(user) {
            FileManager.default.createFile(
                atPath: path,
                contents: data
            )
        }
    }
}


//
//  UserProfileManager.swift
//
//
//  Created by Ethan Brown on 3/22/26.
//

import Foundation

struct UserProfile: Codable {
    let name: String
    let age: Int?
    let hobbies: [String]?
}

class UserProfileManager {
    static let basePath = "/workspace/config/users"
    static func profilePath(for uuid: String) -> String {
        return (basePath as NSString).appendingPathComponent("\(uuid).json")
    }
    static func load(for uuid: String) -> UserProfile? {
        let path = profilePath(for: uuid)
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }
    static func save(_ profile: UserProfile, for uuid: String) {
        let path = profilePath(for: uuid)
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(profile) {
            FileManager.default.createFile(atPath: path, contents: data)
        }
    }
}


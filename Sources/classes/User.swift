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
    var updatedTimestamp: Int64
    
    private static let basePath = "/workspace/users"
    
    init(uuid: String, name: String, notes: [String] = [], updatedTimestamp: Int64 = Int64(Date.now.timeIntervalSince1970)) {
        self.uuid = uuid
        self.name = name
        self.notes = notes
        self.updatedTimestamp = updatedTimestamp
    }
}

extension User {
    
}


//
//  UserInputResponse.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//

struct UserInputResponse: Codable {
    let agentUUID: String
    let userUUID: String
    let accepted: Bool?
    let responseText: String?
}

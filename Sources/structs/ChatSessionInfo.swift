//
//  ChatSessionInfo.swift
//
//
//  Created by Ethan Brown on 3/19/26.
//

import Foundation

struct ChatSessionInfo: Codable {
    let userUUID: String
    var mode: Mode
    var directories: [String] = [DAWSON.root]
}


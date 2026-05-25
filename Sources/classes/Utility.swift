//
//  Utility.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//

import Foundation

class Utility {
    
    static func inSessionDirectories(path: String, session: ChatSessionInfo) -> Bool {
        let fullPath = NSString(string: path).expandingTildeInPath
        let fullURL  = URL(fileURLWithPath: fullPath).standardizedFileURL
        
        return session.directories.contains { dir in
            let dirURL = URL(fileURLWithPath: dir).standardizedFileURL
            return fullURL.path.hasPrefix(dirURL.path)
        }
    }
}

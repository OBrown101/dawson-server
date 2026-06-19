//
//  Utility.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//

import Foundation

class Utility {
    
    static func inSessionDirectories(path: String, directories: [String]) -> Bool {
        let fileURL = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
            .resolvingSymlinksInPath()
            .standardizedFileURL

        return directories.contains { dir in
            let dirURL = URL(fileURLWithPath: NSString(string: dir).expandingTildeInPath)
                .resolvingSymlinksInPath()
                .standardizedFileURL

            return fileURL.path == dirURL.path ||
                   fileURL.path.hasPrefix(dirURL.path + "/")
        }
    }
}

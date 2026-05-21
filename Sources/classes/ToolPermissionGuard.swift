//
//  ToolPermissionGuard.swift
//
//
//  Created by Ethan Brown on 5/17/26.
//

import Foundation

enum ToolPermissionGuardError: Error, LocalizedError {
    case forbidden

    var errorDescription: String? {
        switch self {
        case .forbidden:
            return "Permission denied for this operation based on user's chat mode."
        }
    }
}

class ToolPermissionGuard {
    static func guardAll(session: ChatSessionInfo) throws {
        guard (session.mode.canWrite),
                (session.mode.canRead),
                (session.mode.canCommands),
                (session.mode.canSudo) else { throw ToolPermissionGuardError.forbidden }
    }
    static func guardWrite(to path: String? = nil, session: ChatSessionInfo) throws {
        guard (session.mode.canWrite) else { throw ToolPermissionGuardError.forbidden }
        
        switch (session.mode) {
        case .egg:
            break
        case .fledgling:
            let inDirectories = inSessionDirectories(path: path, session: session)
            guard (inDirectories) else { throw ToolPermissionGuardError.forbidden }
        case .warrior:
            break
        case .ultimate:
            break
        }
    }
    static func guardRead(from path: String? = nil, session: ChatSessionInfo) throws {
        guard (session.mode.canRead) else { throw ToolPermissionGuardError.forbidden }
        
        switch (session.mode) {
        case .egg:
            break
        case .fledgling:
            let inDirectories = inSessionDirectories(path: path, session: session)
            guard (inDirectories) else { throw ToolPermissionGuardError.forbidden }
        case .warrior:
            break
        case .ultimate:
            break
        }
    }
    static func guardCommands(session: ChatSessionInfo) throws {
        guard (session.mode.canCommands) else { throw ToolPermissionGuardError.forbidden }
    }
    static func guardSudo(session: ChatSessionInfo) throws {
        guard (session.mode.canSudo) else { throw ToolPermissionGuardError.forbidden }
    }
}

extension ToolPermissionGuard {
    static func inSessionDirectories(path: String?, session: ChatSessionInfo) -> Bool {
        guard let path = path else { return false }
        let fullPath = NSString(string: path).expandingTildeInPath
        let fullURL  = URL(fileURLWithPath: fullPath).standardizedFileURL

        return session.directories.contains { dir in
            let dirURL = URL(fileURLWithPath: dir).standardizedFileURL
            return fullURL.path.hasPrefix(dirURL.path)
        }
    }
}

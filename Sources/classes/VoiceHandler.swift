//
//  VoiceHandler.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/23/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import Vapor
import NIOConcurrencyHelpers


struct VoiceModelManifest: Content {
    struct Entry: Content {
        let path: String    // relative path, e.g. "kokoro/model.onnx"
        let bytes: Int64
        let sha256: String
    }
    let version: Int
    let files: [Entry]
}

class VoiceHandler: @unchecked Sendable {
    //  Serves voice model files to client (e.g. Beakshield) over HTTPS GET
    //  Uses same Vapor app as main WebSocket (same TLS-cert/bearer-token).
    //  HTTP used instead due to ~400MB of models due to JSON-bloat, no resume, streaming downloads.
    
    static let modelsDirectory = DAWSON.root.appendingPathComponent("voice-models")

    static func register(_ app: Application) throws {
        app.get("voice-models", "manifest") { req async throws -> VoiceModelManifest in
            // GET /voice-models/manifest — recursive listing of available files
            try authorize(req)
            return VoiceModelManifest(version: 1, files: listFiles())
        }

        app.get("voice-models", "file", "**") { req async throws -> Response in
            // GET /voice-models/file/<relative path> — streamed, range-capable
            try authorize(req)

            let relativePath = req.parameters.getCatchall().joined(separator: "/")
            guard !relativePath.isEmpty else { throw Abort(.badRequest) }

            // Path traversal guard: resolve and require containment.
            let root = modelsDirectory.resolvingSymlinksInPath()
            let target = root.appendingPathComponent(relativePath).resolvingSymlinksInPath()
            let rootPrefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
            guard target.path.hasPrefix(rootPrefix),
                  FileManager.default.fileExists(atPath: target.path) else {
                throw Abort(.notFound)
            }

            return try await req.fileio.asyncStreamFile(at: target.path)
        }
    }

    private static func authorize(_ req: Request) throws {
        // Same bearer token as the WebSocket route
        guard (req.headers.bearerAuthorization?.token == (try? WebSocketSecurity.authToken())) else {
            throw Abort(.unauthorized)
        }
    }

    private static func listFiles() -> [VoiceModelManifest.Entry] {
        let root = modelsDirectory
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var entries: [VoiceModelManifest.Entry] = []
        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            let relative = url.path.replacingOccurrences(of: root.path + "/", with: "")
            entries.append(VoiceModelManifest.Entry(path: relative, bytes: Int64(size), sha256: sha256(of: url)))
        }
        return entries.sorted { $0.path < $1.path }
    }
}

extension VoiceHandler {
    
    private static let hashCache = NIOLockedValueBox<[String: (mtime: Date, hash: String)]>([:])

    private static func sha256(of url: URL) -> String {
        let mtime = ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date) ?? .distantPast

        if let cached = hashCache.withLockedValue({ $0[url.path] }),
           (cached.mtime == mtime) {
            return cached.hash
        }

        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return "" }
        let hex = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()

        hashCache.withLockedValue { $0[url.path] = (mtime, hex) }
        return hex
    }
}


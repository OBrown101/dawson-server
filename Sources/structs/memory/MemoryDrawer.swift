//
//  MemoryDrawer.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/4/26.
//

import Foundation

struct MemoryDrawer: Codable {
    var id: String?
    var content: String?        // preview in lists, full text in get_drawer/search
    var wing: String?
    var room: String?
    var sourcePath: String?
    var sourceFile: String?     // basename only from get_drawer, per docs
    var addedBy: String?
    var filedAt: String?        // not documented; captured when present in metadata
    var similarity: Double?     // search results only

    // Inbound: accept documented + plausible key variants.
    private enum In: String, CodingKey {
        case id, drawerId = "drawer_id"
        case content, preview, content_preview, text
        case wing
        case room
        case sourcePath = "source_path"
        case sourceFile = "source_file"
        case addedBy = "added_by"
        case filedAt = "filed_at"
        case similarity
        case metadata
    }

    // Outbound: Dawson's stable wire keys.
    private enum Out: String, CodingKey {
        case id
        case content
        case wing
        case room
        case sourcePath
        case sourceFile
        case addedBy
        case filedAt
        case similarity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: In.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
                ?? c.decodeIfPresent(String.self, forKey: .drawerId)
        content = try c.decodeIfPresent(String.self, forKey: .content)
                    ?? c.decodeIfPresent(String.self, forKey: .preview)
                    ?? c.decodeIfPresent(String.self, forKey: .content_preview)
                    ?? c.decodeIfPresent(String.self, forKey: .text)
        wing = try c.decodeIfPresent(String.self, forKey: .wing)
        room = try c.decodeIfPresent(String.self, forKey: .room)
        sourcePath = try c.decodeIfPresent(String.self, forKey: .sourcePath)
        sourceFile = try c.decodeIfPresent(String.self, forKey: .sourceFile)
        addedBy = try c.decodeIfPresent(String.self, forKey: .addedBy)
        filedAt = try c.decodeIfPresent(String.self, forKey: .filedAt)
        similarity = try c.decodeIfPresent(Double.self, forKey: .similarity)

        // get_drawer nests source_file / added_by / timestamps under metadata.
        if let meta = try? c.decodeIfPresent(MemoryDrawerMetadata.self, forKey: .metadata) {
            sourceFile = sourceFile ?? meta.sourceFile
            addedBy = addedBy ?? meta.addedBy ?? meta.agent
            filedAt = filedAt ?? meta.filedAt
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Out.self)
        try c.encodeIfPresent(id, forKey: .id)
        try c.encodeIfPresent(content, forKey: .content)
        try c.encodeIfPresent(wing, forKey: .wing)
        try c.encodeIfPresent(room, forKey: .room)
        try c.encodeIfPresent(sourcePath, forKey: .sourcePath)
        try c.encodeIfPresent(sourceFile, forKey: .sourceFile)
        try c.encodeIfPresent(addedBy, forKey: .addedBy)
        try c.encodeIfPresent(filedAt, forKey: .filedAt)
        try c.encodeIfPresent(similarity, forKey: .similarity)
    }
}

//
//  AgentName.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/2/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

final class AgentName {

    private static let stems = [
        "Ald", "Alf", "Ash", "Beor", "Bert", "Cen", "Cuth", "Dun", "Ead",
        "Eal", "Eth", "Fen", "God", "Grim", "Har", "Here", "Hild", "Leof",
        "Os", "Sae", "Sig", "Theo", "Thur", "Wil", "Win", "Wulf", "Wig",
        "Aeth", "Bald", "Ord"
    ]

    private static let endings = [
        "ric", "win", "mund", "gar", "stan", "helm", "frith", "ward",
        "bert", "noth", "red", "wald", "sige", "mer", "hun", "grim",
        "wine", "bald", "ley", "ton", "wick", "eth", "wyn", "run", "gild"
    ]

    private static var poolSize: Int {
        (stems.count * endings.count)
    }

    private static func seed(_ string: String) -> UInt64 {
        // Stable FNV-1a hash
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001B3
        }
        return hash
    }

    private static func compose(_ index: Int) -> String {
        let stem = stems[index / endings.count]
        let ending = endings[index % endings.count]
        // Collapse awkward doubled letters at the join ("Bertton" -> "Berton").
        if let last = stem.last,
           let first = ending.first,
           (last == first) {
            return stem + ending.dropFirst()
        }
        return (stem + ending)
    }
    
    static func getNewName(for uuid: String, type: Agent.AgentType, avoiding existing: [String] = []) -> String {
        guard (type != Agent.AgentType.dawson) else { return "" }
        
        let start = Int(seed(uuid) % UInt64(poolSize))
        for offset in 0..<poolSize {
            let candidate = compose((start + offset) % poolSize)
            if (!Set(existing).contains(candidate)) {
                return candidate
            }
        }
        var numeral = 2
        let base = compose(start)
        while existing.contains("\(base) \(numeral)") {
            numeral += 1
        }
        return "\(base) \(numeral)"
    }
}

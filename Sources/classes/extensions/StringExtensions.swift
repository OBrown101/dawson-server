//
//  StringExtensions.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/20/26.
//

import Foundation

extension String {
    func chunked(into size: Int) -> [String] {
        var chunks: [String] = []
        var start = startIndex

        while start < endIndex {
            let end = index(start, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(String(self[start..<end]))
            start = end
        }

        return chunks
    }
}

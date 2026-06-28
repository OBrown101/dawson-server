//
//  StreamTempState.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/26/26.
//

import Foundation

actor StreamTempState {
    private var content = ""
    private var thinking = ""

    func append(content: String) {
        self.content += content
    }

    func append(thinking: String) {
        self.thinking += thinking
    }

    func snapshot() -> (content: String, thinking: String) {
        (content, thinking)
    }
}

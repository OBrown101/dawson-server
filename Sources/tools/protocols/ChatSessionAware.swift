//
//  ChatSessionAware.swift
//
//
//  Created by Ethan Brown on 5/17/26.
//

import Foundation

protocol ChatSessionAware: Tool {
    func setSession(_ session: ChatSessionInfo)
}


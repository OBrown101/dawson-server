//
//  ChatAware.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/17/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

protocol ChatAware: Tool {
    func setChat(_ chat: Chat?)
}


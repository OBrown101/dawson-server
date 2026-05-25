//
//  ToolResult.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/24/26.
//

import Foundation

enum ToolResult {
    case completed(String)
    case suspended(UserInputRequest)
    case denied(String)
}

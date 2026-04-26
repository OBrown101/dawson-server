//
//  MsgSource.swift
//  
//
//  Created by Ethan Brown on 3/25/26.
//

import Foundation

enum MsgSource {
    case user          // (FROM USER) General prompts
    case system        // (FROM USER) Sets behavior, personality, rules
    case assistant     // (FROM LLM)  Model responses
    case tool          // (FROM USER) When returning tool exec results back to the model
    
    var name: String {
        switch self {
        case .user:
            return "user"
        case .system:
            return "system"
        case .assistant:
            return "assistant"
        case .tool:
            return "tool"
        }
    }
    func fromString(_ stringName: String) -> MsgSource {
        switch stringName {
        case MsgSource.user.name:
            return .user
        case MsgSource.system.name:
            return .system
        case MsgSource.assistant.name:
            return .assistant
        case MsgSource.tool.name:
            return .tool
        default:
            return .user
        }
    }
}

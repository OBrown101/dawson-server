//
//  ToolStructs.swift
//  
//
//  Created by Ethan Brown on 3/22/26.
//

import Foundation
import AnyCodable

struct ToolCall: Codable {
    let name: String
    let arguments: [String: AnyCodable]
    
    enum CodingKeys: String, CodingKey {
        case name
        case arguments
    }
    
    static func fromOllamaToolJSON(_ json: [[String: Any]]?) -> [ToolCall]? {
        guard let json = json else { return nil }
        
        var toolCalls: [ToolCall] = []
        for callDict in json {
            guard let function = callDict["function"] as? [String: Any] else {
                print("Missing 'function' key in tool call")
                continue
            }

            guard let name = function["name"] as? String else {
                print("Missing 'name' in function")
                continue
            }

            let arguments = function["arguments"] as? [String: Any] ?? [:]
            let anyCodableArgs = arguments.mapValues { AnyCodable($0) }

            let toolCall = ToolCall(name: name, arguments: anyCodableArgs)
            toolCalls.append(toolCall)
        }

        return toolCalls.isEmpty ? nil : toolCalls
    }
    
    var argDict: [String: Any] {
        arguments.mapValues { $0.value }
    }
}

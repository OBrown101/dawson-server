//
//  ToolStructs.swift
//  
//
//  Created by Ethan Brown on 3/22/26.
//

import Foundation
@preconcurrency import AnyCodable

struct ToolCall: Codable, Sendable {
    let name: String
    let arguments: [String: AnyCodable]
    
    enum CodingKeys: String, CodingKey {
        case name
        case arguments
    }
    
    static func fromProviderToolJSON(_ json: [[String: Any]]?) -> [ToolCall]? {
        guard let json else { return nil }

        var toolCalls: [ToolCall] = []
        for callDict in json {
            var name: String?
            var arguments: [String: Any] = [:]

            if let function = callDict["function"] as? [String: Any] {
                name = function["name"] as? String
                arguments = function["arguments"] as? [String: Any] ?? [:]
            } else {
                name = callDict["name"] as? String

                if let input = callDict["input"] as? [String: Any] {
                    arguments = input
                } else if let args = callDict["arguments"] as? [String: Any] {
                    arguments = args
                } else if let args = callDict["arguments"] as? String,
                          let data = args.data(using: .utf8),
                          let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    arguments = decoded
                }
            }

            guard let name,
                  !name.isEmpty else {
                print("Missing tool call name:", callDict)
                continue
            }

            toolCalls.append(ToolCall(name: name, arguments: arguments.mapValues { AnyCodable($0) }))
        }

        return toolCalls.isEmpty ? nil : toolCalls
    }
    
    var argDict: [String: Any] {
        arguments.mapValues { $0.value }
    }
}

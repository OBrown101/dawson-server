//
//  ToolStructs.swift
//  
//
//  Created by Ethan Brown on 3/22/26.
//

import Foundation
@preconcurrency import AnyCodable

struct ToolCall: Codable, Sendable {
    let id: String?
    let name: String
    let arguments: [String: AnyCodable]
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case arguments
    }
    
    var argDict: [String: Any] {
        arguments.mapValues { $0.value }
    }
    
    static func fromProviderToolJSON(providerType: ProviderClient.ProviderType, _ json: [[String: Any]]?) -> [ToolCall]? {
        guard let json else { return nil }
        
        let toolCalls: [ToolCall] = json.compactMap { callDict in
            switch providerType {
            case .ollama:
                return fromOllama(callDict)

            case .openai:
                return fromOpenAI(callDict)

            case .anthropic:
                return fromAnthropic(callDict)
            }
        }

        return toolCalls.isEmpty ? nil : toolCalls
    }

    private static func fromOllama(_ callDict: [String: Any]) -> ToolCall? {
        guard let function = callDict["function"] as? [String: Any],
              let name = function["name"] as? String else {
            print("Invalid Ollama tool call:", callDict)
            return nil
        }

        let id = callDict["id"] as? String
        let arguments = function["arguments"] as? [String: Any] ?? [:]

        return ToolCall(id: id, name: name, arguments: arguments.mapValues { AnyCodable($0) })
    }
    
    private static func fromOpenAI(_ callDict: [String: Any]) -> ToolCall? {
        guard let name = callDict["name"] as? String else {
            print("Invalid OpenAI tool call:", callDict)
            return nil
        }

        let id = callDict["call_id"] as? String ?? callDict["id"] as? String
        var arguments: [String: Any] = [:]

        if let args = callDict["arguments"] as? String,
           let data = args.data(using: .utf8),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            arguments = decoded
        } else if let args = callDict["arguments"] as? [String: Any] {
            arguments = args
        }

        return ToolCall(id: id, name: name, arguments: arguments.mapValues { AnyCodable($0) })
    }
    
    private static func fromAnthropic(_ callDict: [String: Any]) -> ToolCall? {
        guard let name = callDict["name"] as? String else {
            print("Invalid Anthropic tool call:", callDict)
            return nil
        }

        let id = callDict["id"] as? String
        let arguments = callDict["input"] as? [String: Any] ?? [:]

        return ToolCall(
            id: id,
            name: name,
            arguments: arguments.mapValues { AnyCodable($0) }
        )
    }
    
    /*
    static func fromProviderToolJSON(providerType: ProviderClient.ProviderType, _ json: [[String: Any]]?) -> [ToolCall]? {
        guard let json else { return nil }

        var toolCalls: [ToolCall] = []
        for callDict in json {
            var id: String?
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
    */
}

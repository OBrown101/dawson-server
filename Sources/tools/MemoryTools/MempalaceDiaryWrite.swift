//
//  MempalaceDiaryWrite.swift
//
//
//  Created by Ethan Brown on 4/27/26.
//

import Foundation

class MempalaceDiaryWrite: Tool {
    let name = "mempalace_diary_write"
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": name,
            "description": "Write to your personal agent diary in AAAK format. Your observations, thoughts, what you worked on, what matters. Each agent has their own diary with full history. Write in AAAK for compression — e.g. 'SESSION:2026-04-04|built.palace.graph+diary.tools|ALC.req:agent.diaries.in.aaak|★★★'. Use entity codes from the AAAK spec.",
            "parameters": [
                "type": "object",
                "required": ["agent_name", "entry"],
                "properties": [
                    "agent_name": [
                        "type": "string",
                        "description": "Your name — each agent gets their own diary wing"
                    ],
                    "entry": [
                        "type": "string",
                        "description": "Your diary entry in AAAK format — compressed, entity-coded, emotion-marked"
                    ],
                    "topic": [
                        "type": "string",
                        "description": "Topic tag (optional, default: general)"
                    ]
                ]
            ]
        ]
    }
    
    func anthropicSchema() -> [String : Any] {
        return [
            "name": name,
            "description": "Write to your personal agent diary in AAAK format. Your observations, thoughts, what you worked on, what matters. Each agent has their own diary with full history. Write in AAAK for compression — e.g. 'SESSION:2026-04-04|built.palace.graph+diary.tools|ALC.req:agent.diaries.in.aaak|★★★'. Use entity codes from the AAAK spec.",
            "input_schema": [
                "type": "object",
                "required": ["agent_name", "entry"],
                "properties": [
                    "agent_name": [
                        "type": "string",
                        "description": "Your name — each agent gets their own diary wing"
                    ],
                    "entry": [
                        "type": "string",
                        "description": "Your diary entry in AAAK format — compressed, entity-coded, emotion-marked"
                    ],
                    "topic": [
                        "type": "string",
                        "description": "Topic tag (optional, default: general)"
                    ]
                ]
            ]
        ]
    }
    
    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Write to your personal agent diary in AAAK format. Your observations, thoughts, what you worked on, what matters. Each agent has their own diary with full history. Write in AAAK for compression — e.g. 'SESSION:2026-04-04|built.palace.graph+diary.tools|ALC.req:agent.diaries.in.aaak|★★★'. Use entity codes from the AAAK spec.",
                "parameters": [
                    "type": "object",
                    "required": ["agent_name", "entry"],
                    "properties": [
                        "agent_name": [
                            "type": "string",
                            "description": "Your name — each agent gets their own diary wing"
                        ],
                        "entry": [
                            "type": "string",
                            "description": "Your diary entry in AAAK format — compressed, entity-coded, emotion-marked"
                        ],
                        "topic": [
                            "type": "string",
                            "description": "Topic tag (optional, default: general)"
                        ]
                    ]
                ]
            ]
        ]
    }
    
    func execute(args: [String: Any]) -> String {
        print("DIARY WRITE (\(args["agent_name"] ?? "")): ", args["entry"] ?? "")
        return MempalaceMemory.shared.mempalaceExec(name: name, args: args)
    }
}

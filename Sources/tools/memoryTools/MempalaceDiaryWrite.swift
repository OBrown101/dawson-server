//
//  MempalaceDiaryWrite.swift
//
//
//  Created by Ethan Brown on 4/27/26.
//

import Foundation

class MempalaceDiaryWrite: Tool {
    static let name = "mempalace_diary_write"
    
    private let toolDescription = """
    Write to your personal agent diary in AAAK format. Your observations, thoughts, what you worked on, what matters. Each agent has their own diary with full history. Write in AAAK for compression — e.g. 'SESSION:2026-04-04|built.palace.graph+diary.tools|ALC.req:agent.diaries.in.aaak|★★★'. Use entity codes from the AAAK spec.
    """
    
    private let parameterSchema: [String: Any] = [
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
            ],
            "wing": [
                "type": "string",
                "description": "Target wing for this diary entry (optional). If omitted, uses wing_{agent_name}. Use this to write diary entries to a project wing instead of an agent-specific wing."
            ]
        ]
    ]
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": MempalaceDiaryWrite.name,
            "description": toolDescription,
            "parameters": parameterSchema
        ]
    }

    func anthropicSchema() -> [String : Any] {
        return [
            "name": MempalaceDiaryWrite.name,
            "description": toolDescription,
            "input_schema": parameterSchema
        ]
    }

    func ollamaSchema() -> [String : Any] {
        return [
            "type": "function",
            "function": [
                "name": MempalaceDiaryWrite.name,
                "description": toolDescription,
                "parameters": parameterSchema
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        return await MempalaceMemory.shared.mempalaceExec(name: MempalaceDiaryWrite.name, args: args)
    }
}

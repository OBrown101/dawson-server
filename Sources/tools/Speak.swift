//
//  SystemSpeakTool.swift
//
//  Created by Ethan Brown on 3/23/26.
//

import Foundation
#if os(macOS)
import AppKit
#endif

class Speak: Tool {
    let name = "system_speak"
    
    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": name,
            "description": "Uses the system's built-in TTS to speak text.",
            "parameters": [
                "type": "object",
                "required": ["text"],
                "properties": [
                    "text": [
                        "type": "string",
                        "description": "Text to speak"
                    ],
                    "voice": [
                        "type": "string",
                        "description": "Optional voice name if supported by OS"
                    ]
                ]
            ]
        ]
    }
    
    func anthropicSchema() -> [String : Any] {
        return [
            "name": name,
            "description": "Uses the system's built-in TTS to speak text.",
            "input_schema": [
                "type": "object",
                "required": ["text"],
                "properties": [
                    "text": [
                        "type": "string",
                        "description": "Text to speak"
                    ],
                    "voice": [
                        "type": "string",
                        "description": "Optional voice name if supported by OS"
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
                "description": "Uses the system's built-in TTS to speak text.",
                "parameters": [
                    "type": "object",
                    "required": ["text"],
                    "properties": [
                        "text": ["type": "string", "description": "Text to speak"],
                        "voice": ["type": "string", "description": "Optional voice name if supported by OS"]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let text = args["text"] as? String else {
            return "Error: text is required."
        }
        let voice = args["voice"] as? String

        #if os(macOS)
        speakMacOS(text, voice: voice)
        #endif
        return "Spoken"
    }

    #if os(macOS)
    private func speakMacOS(_ text: String, voice: String?) {
        let synth = NSSpeechSynthesizer()
        synth.startSpeaking(text)
    }
    #endif
}

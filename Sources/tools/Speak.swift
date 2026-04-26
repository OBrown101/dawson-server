//
//  SystemSpeakTool.swift
//
//  Created by Ethan Brown on 3/23/26.
//

import Foundation
import AppKit

class Speak: Tool {
    let name = "system_speak"

    func schema() -> [String: Any] {
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

    func execute(args: [String: Any]) -> String {
        guard let text = args["text"] as? String else {
            return "Error: text is required."
        }
        let voice = args["voice"] as? String

        #if os(macOS)
        return speakMacOS(text: text, voice: voice)
        #elseif os(Windows)
        return speakWindows(text: text, voice: voice)
        #else
        return speakLinux(text: text)
        #endif
    }

    // MARK: - macOS
    private func speakMacOS(text: String, voice: String?) -> String {
        let synthesizer = NSSpeechSynthesizer()
        if let voice = voice {
            synthesizer.setVoice(NSSpeechSynthesizer.VoiceName(rawValue: voice))
        }
        synthesizer.startSpeaking(text)
        return "Speaking on macOS: \(text)"
    }

    // MARK: - Windows
    private func speakWindows(text: String, voice: String?) -> String {
        return ""
    }

    // MARK: - Linux
    private func speakLinux(text: String) -> String {
        let process = Process()
        process.launchPath = "/usr/bin/env"
        process.arguments = ["spd-say", text]
        process.launch()
        return "Speaking on Linux: \(text)"
    }
}

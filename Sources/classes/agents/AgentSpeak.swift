//
//  AgentSpeak.swift
//  
//
//  Created by Ethan Brown on 3/31/26.
//

import Foundation

// IN PROGRESS -- NOT READY FOR USE

class AgentSpeak {
//    static let shared = AgentSpeak()
//    
//    private var queue = [String]()
//    private var buffer = ""
//    private let queueLock = DispatchQueue(label: "AgentSpeakQueue")
//    
//    private let piperPath: String
//    private let voiceFilePath: String
//    
//    private init() {
//        // Make paths relative to your workspace/project
//        let workspace = ("~/DAWSON/TTS" as NSString).expandingTildeInPath
//        self.piperPath = workspace + "/piper_executable"       // Your Piper executable
//        self.voiceFilePath = workspace + "/voices/my_voice.pt" // Your Piper voice
//    }
//    
//    func speakChunk(_ chunk: String) {
//        queueLock.async {
//            self.buffer += chunk
//            
//            // Split on sentence-ending punctuation or newlines
//            while let range = self.buffer.range(of: "[.!?]\\s+", options: .regularExpression) {
//                let sentence = String(self.buffer[..<range.upperBound])
//                self.queue.append(sentence)
//                self.buffer = String(self.buffer[range.upperBound...])
//            }
//            
//            self.startNextIfNeeded()
//        }
//    }
//    
//    private func startNextIfNeeded() {
//        guard !queue.isEmpty else { return }
//        let text = queue.removeFirst()
//
//        DispatchQueue.global(qos: .userInitiated).async {
//            let process = Process()
//            let workspace = ("~/DAWSON/TTS" as NSString).expandingTildeInPath
//            let scriptPath = workspace + "/piper_wrapper.py"
//
//            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
//            process.arguments = ["python3", scriptPath, text]
//
//            do {
//                try process.run()
//                process.waitUntilExit()
//            } catch {
//                print("Error running Piper wrapper: \(error)")
//            }
//
//            self.queueLock.async {
//                self.startNextIfNeeded()
//            }
//        }
//    }
}

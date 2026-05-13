//
//  LLMClient.swift
//  
//
//  Created by Ethan Brown on 3/22/26.
//

import Foundation

final class LLMClient: Sendable {
    static let shared = LLMClient()
    
    enum LLMType {
        case ollama

        var url: String {
            switch self {
            case .ollama:
                return "http://localhost:11434/api/chat"
            }
        }
    }
    
    func streamJSON(llmType: LLMType, payload: [String: Any]) -> AsyncThrowingStream<Data, Error> {
        let payloadData: Data
        do {
            payloadData = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            return AsyncThrowingStream { @Sendable continuation in
                continuation.finish(throwing: error)
            }
        }
        
        return AsyncThrowingStream { @Sendable continuation in
            let task = Task {
                do {
                    guard let url = URL(string: llmType.url) else {
                        throw NSError(domain: "LLMClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                    }
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = payloadData
                    
                    let sessionConfig = URLSessionConfiguration.default
                    sessionConfig.timeoutIntervalForRequest = 800
                    sessionConfig.timeoutIntervalForResource = 800
                    let session = URLSession(configuration: sessionConfig)
                    
                    let (bytes, response) = try await session.bytes(for: request)
                    
                    if let httpResponse = response as? HTTPURLResponse,
                       !(200...299).contains(httpResponse.statusCode) {
                        throw NSError(domain: "LLMClient", code: httpResponse.statusCode)
                    }
                    
                    for try await line in bytes.lines {
                        guard let data = line.data(using: .utf8) else { continue }
                        
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            let jsonData = try JSONSerialization.data(withJSONObject: json)
                            continuation.yield(jsonData)
                            
                            // Detects completion for Ollama providers (needs handling for other provider types)
                            if let done = json["done"] as? Bool,
                               (done) {
                                break
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
                
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

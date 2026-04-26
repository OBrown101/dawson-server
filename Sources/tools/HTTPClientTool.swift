//
//  HTTPClientTool.swift
//  
//
//  Created by Ethan Brown on 3/31/26.
//

import Foundation

class HTTPClientTool: Tool {
    let name = "http_client"

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Performs GET or POST HTTP requests.",
                "parameters": [
                    "type": "object",
                    "required": ["url", "method"],
                    "properties": [
                        "url": ["type": "string", "description": "URL to request"],
                        "method": ["type": "string", "description": "GET or POST"],
                        "body": ["type": "string", "description": "Optional POST body"]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) -> String {
        guard let urlStr = args["url"] as? String,
              let method = args["method"] as? String,
              let url = URL(string: urlStr) else {
            return "Error: Invalid URL or method."
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.uppercased()
        if let body = args["body"] as? String, method.uppercased() == "POST" {
            request.httpBody = body.data(using: .utf8)
        }

        let semaphore = DispatchSemaphore(value: 0)
        var result = ""
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                result = "Error: \(error.localizedDescription)"
            } else if let data = data, let str = String(data: data, encoding: .utf8) {
                result = str
            } else {
                result = "No data returned."
            }
            semaphore.signal()
        }.resume()
        semaphore.wait()
        return result
    }
}

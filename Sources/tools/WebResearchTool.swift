//
//  WebScraper.swift
//  
//
//  Created by Ethan Brown on 3/31/26.
//

import Foundation

class WebResearchTool: Tool {
    let name = "web_research_tool"

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Searches the web for a query, fetches top results, and returns cleaned readable text for AI reasoning.",
                "parameters": [
                    "type": "object",
                    "required": ["query"],
                    "properties": [
                        "query": [
                            "type": "string",
                            "description": "Search query or topic (e.g., 'latest AI news')"
                        ],
                        "maxResults": [
                            "type": "integer",
                            "description": "Maximum number of search results to fetch",
                            "default": 5
                        ],
                        "keywords": [
                            "type": "array",
                            "description": "Optional keywords to filter content"
                        ]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) -> String {
        guard let query = args["query"] as? String else {
            return "Error: 'query' is required."
        }
        let maxResults = args["maxResults"] as? Int ?? 5
        let keywords = args["keywords"] as? [String]

        // 1️⃣ Search for top result URLs
        let urls = searchDuckDuckGo(query: query, maxResults: maxResults)
        if urls.isEmpty { return "No search results found." }

        var output = "Search Results for: \(query)\n\n"

        // 2️⃣ Fetch each page and clean content
        for (index, url) in urls.enumerated() {
            output += "Result \(index + 1): \(url.absoluteString)\n"
            let content = fetchAndClean(url: url)

            // 3️⃣ Apply keyword filter if needed
            let filteredContent: String
            if let keywords = keywords, !keywords.isEmpty {
                filteredContent = content
                    .components(separatedBy: .whitespacesAndNewlines)
                    .filter { word in
                        keywords.contains(where: { word.localizedCaseInsensitiveContains($0) })
                    }
                    .joined(separator: " ")
            } else {
                filteredContent = content
            }

            let snippet = String(filteredContent.prefix(2000)) // Limit size for LLM
            output += "Content Preview:\n\(snippet)\n-----------------------\n"
        }

        return output
    }

    // MARK: - Search Engine
    private func searchDuckDuckGo(query: String, maxResults: Int) -> [URL] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://duckduckgo.com/html/?q=\(encodedQuery)") else { return [] }

        guard let html = try? String(contentsOf: url) else { return [] }

        // Basic regex for result links
        let pattern = "<a rel=\"nofollow\" class=\"result__a\" href=\"(.*?)\">"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }

        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.count))
        var urls: [URL] = []
        for match in matches.prefix(maxResults) {
            if let range = Range(match.range(at: 1), in: html),
               let url = URL(string: String(html[range])) {
                urls.append(url)
            }
        }
        return urls
    }

    // MARK: - Fetch & Clean
    private func fetchAndClean(url: URL) -> String {
        guard let data = try? Data(contentsOf: url),
              let html = String(data: data, encoding: .utf8) else { return "Failed to fetch page." }

        // Remove scripts, styles, and HTML tags
        var cleaned = html.replacingOccurrences(of: "(?s)<script.*?>.*?</script>", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "(?s)<style.*?>.*?</style>", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // Normalize whitespace
        cleaned = cleaned
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "  ", with: " ")

        return cleaned
    }
}

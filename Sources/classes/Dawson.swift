import Foundation

class DAWSON {
    let server: WebSocketServer
    
    static let root = FileManager.default.currentDirectoryPath
    static let workspace = (root + "/workspace" as NSString).expandingTildeInPath

    let firstUserPrompt = "Hello, wake up and be ready to take commands."
    let defaultMaxMessage = 20
    let defaultModel = "gpt-oss-20b-32k-16k"  // "qwen3.5-tools"
    let primaryAgentUUID = "PRIMARY"
    
    var activeAgents: [String: Agent] = [:]

    init() {
        server = WebSocketServer()
        server.dawson = self
        
        let _ = spawnAgent(uuid: primaryAgentUUID, type: .dawson, model: defaultModel)     // Sets up primary Dawson agent
    }
    
    func spawnAgent(uuid: String, type: AgentType, model: String? = nil) -> Agent {
        let newAgent = Agent(
            uuid: uuid,
            type: type,
            model: model ?? defaultModel,
            maxMessages: defaultMaxMessage,
            tools: [
                MCPTool(), WriteFile(), SearchFileContents(), IndexFileContents(), ReadFileRange(), ReadFile(), Speak(), SelfConfig(), FileSearch(),
                RichFormatter(), TextSearch()
            ]   // These will change to support based on mode/settings
        )
        
        activeAgents[uuid] = newAgent
        return newAgent
    }
    
    func run(agentUUID: String, prompt: String, onEvent: ((_ event: AgentEvent, _ sessionUUID: String) -> Void)? = nil) async -> [Message] {
        guard let agent = activeAgents[agentUUID] else { return [] }

        let systemPrompt = (agent.getHistory().isEmpty) ? Loader.shared.buildBaseSystemPrompt(agent: agent.type) : ""
        let (_, messages) = await agent.runAgent(userPrompt: prompt, systemPrompt: systemPrompt, onEvent: onEvent)
        return messages
    }
}

import Foundation

class DAWSON {
    let server: WebSocketServer
    
    let WORKSPACE = ("~/DAWSON/workspace" as NSString).expandingTildeInPath

    let firstUserPrompt = "Hello, wake up and be ready to take commands."
    let defaultMaxMessage = 20
    let defaultModel = "qwen3.5:9b"
    let primaryAgentUUID = "PRIMARY"
    
    var activeAgents: [String: Agent] = [:]

    init() {
        activeAgents[primaryAgentUUID] = Agent(
            uuid: primaryAgentUUID,
            type: .primary,
            model: defaultModel,
            maxMessages: defaultMaxMessage)
        
        server = WebSocketServer()
        server.dawson = self
    }
    
    func spawnAgent(uuid: String, type: AgentType, model: String? = nil) -> Agent {
        let newAgent = Agent(
            uuid: uuid,
            type: type,
            model: model ?? defaultModel,
            maxMessages: defaultMaxMessage,
            tools: [
                WriteFile(), ReadFile(), Speak(), SpotifyTool(), SelfConfig(), FileSearch(),
                AlertTool(), HTTPClientTool(), ProcessMonitor(), RichFormatter(), SQLDatabaseTool(),
                JSONValidator(), SystemInfo(), TextSearch(), CSVParser()
            ]   // These will change to support based on mode/settings
        )
        
        activeAgents[uuid] = newAgent
        return newAgent
    }
    
    func run(agentUUID: String, prompt: String, onEvent: ((_ event: AgentEvent, _ sessionUUID: String) -> Void)? = nil) async -> [Message] {
        guard let agent = activeAgents[agentUUID] else { return [] }

        let systemPrompt = (agent.getHistory().isEmpty) ? Loader.shared.buildSystemContent() : nil
        let (_, messages) = await agent.runAgent(userPrompt: prompt, systemPrompts: systemPrompt, onEvent: onEvent)
        return messages
    }
}

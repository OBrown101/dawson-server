import Foundation

class DAWSON {
    let server: WebSocketServer
    let memory = Memory()
    
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
            memory: memory,
            maxMessages: defaultMaxMessage)
        
        server = WebSocketServer()
        server.dawson = self
    }
    
    func spawnAgent(uuid: String, type: AgentType, model: String? = nil) -> Agent {
        let newAgent = Agent(
            uuid: uuid,
            type: type,
            model: model ?? defaultModel,
            memory: memory,
            maxMessages: defaultMaxMessage
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

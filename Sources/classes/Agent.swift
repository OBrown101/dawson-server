import Foundation


enum AgentEvent: Hashable {
    case content(String = "")
    case thinking(String = "")
    case toolCall(String = "")
    case toolResult(String = "")
}

enum AgentType {
    case primary
    case squireBot
    
    var name: String {
        switch (self) {
        case .primary:
            "primary"
        case .squireBot:
            "squire_bot"
        }
    }
}

class Agent {
    let uuid: String
    let llmType: LLMClient.LLMType
    let type: AgentType
    let model: String
    let memory: Memory
    let maxIterations: Int
    var maxMessages: Int
    var history: [Message]
    var tools: [Tool]

    var provider: LLMProvider

    init(
        uuid: String,
        llmType: LLMClient.LLMType = .ollama,
        type: AgentType,
        model: String,
        memory: Memory,
        maxIterations: Int = 5,
        maxMessages: Int = 20,
        history: [Message] = [],
        tools: [Tool] = [WriteFile(), ReadFile(), Speak(), SpotifyTool(), SelfConfig(), FileSearch(), AlertTool(), HTTPClientTool(), ProcessMonitor(), RichFormatter(), SQLDatabaseTool(), JSONValidator(), SystemInfo(), TextSearch(), CSVParser()]
    ) {
        self.uuid = uuid
        self.llmType = llmType
        self.type = type
        self.model = model
        self.memory = memory
        self.maxIterations = maxIterations
        self.maxMessages = maxMessages
        self.history = history
        self.tools = tools

        provider = Provider.provider(for: llmType)
    }
    
    func trimMessages(_ messages: [Message], recentWindow: Int = 50, keepSystemPrompt: Bool) -> [Message] {
        guard (!messages.isEmpty) else { return [] }
        
        let systemMessages = messages.filter { $0.role == MsgSource.system.name }
        let nonSystemMessages = messages.filter { $0.role != MsgSource.system.name }
        
        // Keep only the last maxMessages of non-system messages
        let trimmed = nonSystemMessages.suffix(recentWindow)
        
        // Combine system messages + trimmed recent messages
        return keepSystemPrompt ? (systemMessages + trimmed) : Array(trimmed)
    }
    
    func runTool(_ toolCall: ToolCall) async -> String {
        guard let tool = tools.first(where: { $0.name == toolCall.name }) else {
            return ("Error: unknown tool '\(toolCall.name)'")
        }
        return tool.execute(args: toolCall.argDict)
    }

    func runAgent(
        userPrompt: String,
        systemPrompts: [String]? = nil,
        useThinking: Bool = true,
        onEvent: ((_ event: AgentEvent, _ sessionUUID: String) -> Void)? = nil
    ) async -> (error: String?, messages: [Message]) {
        let sessionUUID = UUID().uuidString
        var newMessages: [Message] = []
        
        if let systemPrompts = systemPrompts,
           (!systemPrompts.isEmpty) {
            let systemMsg = systemPrompts.map({ Message(role: MsgSource.system.name, text: $0) })
            newMessages.append(contentsOf: systemMsg)
        }
        
        let userMsg = Message(role: MsgSource.user.name, text: userPrompt)
        newMessages.append(userMsg)
        
        var iterations = 0
        while (iterations < maxIterations) {
            let keepSystemPrompt = ((systemPrompts != nil) && (iterations == 0))
            
//            let memoryMessages = await memory.getContext(userPrompt: userPrompt, agentHistory: history)
//            let memoryMessages: [Message] = await memory.getContext(query: userPrompt)
            let memoryMessages: [Message] = []
            let promptMessages = trimMessages((memoryMessages + newMessages), keepSystemPrompt: keepSystemPrompt)
            
            let response = await provider.send(
                messages: promptMessages,
                model: model,
                tools: tools,
                useThinking: useThinking,
                onUpdate: { response in
                    if !response.thinking.isEmpty {
                        onEvent?(.thinking(response.thinking), sessionUUID)
                    }
                    if !response.content.isEmpty {
                        onEvent?(.content(response.content), sessionUUID)
                    }
                }
            )
            let responseMsg = Message.fromProvider(response)
            newMessages.append(responseMsg)
            
            // No tools → final respons
            guard let toolCalls = responseMsg.toolCalls,
                  (!toolCalls.isEmpty) else {
                // print("No tool calls")
                history.append(contentsOf: newMessages)
                return (nil, newMessages)
            }
            
            // Execute tools
            var toolResults: [Message] = []
            for tc in toolCalls {
                onEvent?(.toolCall(tc.name), sessionUUID)
                let result = await runTool(tc)
                onEvent?(.toolResult(result), sessionUUID)
                
                let tcResultMsg = Message(role: MsgSource.tool.name, text: ("Tool Usage Result: " + result))
                toolResults.append(tcResultMsg)
            }
            newMessages.append(contentsOf: toolResults)
            iterations += 1
        }
        
        history.append(contentsOf: newMessages)
        let fullText = newMessages.compactMap { $0.text }.joined(separator: "\n")
        await memory.store(text: fullText)
        return (nil, newMessages)
    }
}

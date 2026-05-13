import Foundation


enum AgentEvent: Hashable {
    case content(String = "")
    case thinking(String = "")
    case toolCall(String = "")
    case toolResult(String = "")
}

enum AgentType {
    case dawson
    case squireBot
    
    var name: String {
        switch (self) {
        case .dawson:
            "agent_dawson"
        case .squireBot:
            "agent_squirebot"
        }
    }
    
    var soulPath: String {
        switch (self) {
        case .dawson:
            "/workspace/config/DAWSON_SOUL.md"
        case .squireBot:
            "/workspace/config/SQUIREBOT_SOUL.md"
        }
    }
    
    static func fromName(_ name: String) -> AgentType? {
        switch name {
        case self.dawson.name:
            return .dawson
        case self.squireBot.name:
            return .squireBot
        default:
            return nil
        }
    }
}

class Agent {
    let uuid: String
    let llmType: LLMClient.LLMType
    let type: AgentType
    let model: String
    let maxIterations: Int
    var maxMessages: Int
    var history: [Message]
    var tools: [Tool]

    var provider: LLMProvider
    
    static var requiredTools: [Tool] {
        return [
            EnvAwareness(),
//            MempalaceAddDrawer(), MempalaceCheckDuplicate(), MempalaceDeleteDrawer(), MempalaceDiaryRead(),
//            MempalaceDiaryWrite(), MempalaceGetAAAKSpec(), MempalaceGraphStats(),
//            MempalaceKgInvalidate(), MempalaceKgQuery(), MempalaceKgStats(), MempalaceKgTimeline(),
//            MempalaceListRooms(), MempalaceListWings(), MempalaceSearch(),
//            MempalaceStatus(), MempalaceTraverse()
        ]
    }

    init(
        uuid: String,
        llmType: LLMClient.LLMType = .ollama,
        type: AgentType,
        model: String,
        maxIterations: Int = 15,
        maxMessages: Int = 40,
        history: [Message] = [],
        tools: [Tool] = []
    ) {
        self.uuid = uuid
        self.llmType = llmType
        self.type = type
        self.model = model
        self.maxIterations = maxIterations
        self.maxMessages = maxMessages
        self.history = history
        self.tools = (Agent.requiredTools + tools)

        provider = Provider.provider(for: llmType)
    }
    
    func getHistory() -> [Message] {
        return history
    }
    
    func trimMessages(_ messages: [Message], recentWindow: Int = 200) -> [Message] {
        let systemMessages = messages.filter { $0.role == MsgSource.system.name }
        let nonSystemMessages = messages.filter { $0.role != MsgSource.system.name }
        let trimmed = nonSystemMessages.suffix(recentWindow)
        
        return (systemMessages + trimmed)
    }
    
    func runTool(_ toolCall: ToolCall) async -> String {
        guard let tool = tools.first(where: { $0.name == toolCall.name }) else {
            return ("Error: unknown tool '\(toolCall.name)'")
        }
        return await tool.execute(args: toolCall.argDict)
    }

    func runAgent(
        userPrompt: String,
        systemPrompt: String = "",
        useThinking: Bool = true,
        onEvent: ((_ event: AgentEvent, _ sessionUUID: String) -> Void)? = nil
    ) async -> (error: String?, messages: [Message]) {
        let sessionUUID = UUID().uuidString
        var newMessages: [Message] = []
        
        if (!systemPrompt.isEmpty) {
            let systemMsg = Message(role: MsgSource.system.name, text: systemPrompt)
            newMessages.append(systemMsg)
        }
        
        let context = MempalaceMemory.shared.getPromptContext(query: userPrompt)
        let contextMsg = Message(role: MsgSource.assistant.name, text: context)
        newMessages.append(contextMsg)
        
        let userMsg = Message(role: MsgSource.user.name, text: userPrompt)
        newMessages.append(userMsg)
        
        let trimmedSessionHistory = trimMessages(history)
//        print("Trimmed Session History: " + String(describing: trimmedSessionHistory.map { $0.text }))
        
        var iterations = 0
        while (iterations < maxIterations) {
            let promptMessage = (trimmedSessionHistory + newMessages)
            
            let response = await provider.send(
                messages: promptMessage,
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
                MempalaceMemory.shared.addConvHistory(messages: newMessages, agent: type)
                return (nil, newMessages)
            }
            
            // Execute tools
            var toolResults: [Message] = []
            for tc in toolCalls {
                print("Calling tool: \(tc.name)...")
                onEvent?(.toolCall(tc.name), sessionUUID)
                let result = await runTool(tc)
                onEvent?(.toolResult(result), sessionUUID)
                print("Tool result: \(result)")
                
                let tcResultMsg = Message(role: MsgSource.tool.name, text: result)
                toolResults.append(tcResultMsg)
            }
            newMessages.append(contentsOf: toolResults)
            iterations += 1
        }
        
        history.append(contentsOf: newMessages)
        MempalaceMemory.shared.addConvHistory(messages: newMessages, agent: type)
        return (nil, newMessages)
    }
}

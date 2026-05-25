import Foundation


enum AgentEvent {
    case content(String = "")
    case thinking(String = "")
    case toolCall(String = "")
    case toolResult(String = "")
    case userInputRequest(UserInputRequest)
    
    var key: String {
        switch self {
        case .content: return "content"
        case .thinking: return "thinking"
        case .toolCall: return "toolCall"
        case .toolResult: return "toolResult"
        case .userInputRequest: return "userInputRequest"
        }
    }
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
    var maxMessages: Int
    var history: [Message]
    var tools: [Tool]
    let saveChatSession: (ChatSuspendData) -> Void

    var provider: LLMProvider

    static var requiredTools: [Tool] {
        return [
            RequestUserInput(), EnvAwareness(), GetFullSkill(), GetSessionInfo(),
            MempalaceAddDrawer(), MempalaceCheckDuplicate(), MempalaceDeleteDrawer(), MempalaceDiaryRead(),
            MempalaceDiaryWrite(), MempalaceGetAAAKSpec(), MempalaceGraphStats(),
            MempalaceKgInvalidate(), MempalaceKgQuery(), MempalaceKgStats(), MempalaceKgTimeline(),
            MempalaceListRooms(), MempalaceListWings(), MempalaceSearch(),
            MempalaceStatus(), MempalaceTraverse()
        ]
    }

    init(
        uuid: String,
        llmType: LLMClient.LLMType = .ollama,
        type: AgentType,
        model: String,
        maxMessages: Int = 40,
        history: [Message] = [],
        tools: [Tool] = [],
        saveChatSession: @escaping (ChatSuspendData) -> Void
    ) {
        self.uuid = uuid
        self.llmType = llmType
        self.type = type
        self.model = model
        self.maxMessages = maxMessages
        self.history = history
        self.tools = (Agent.requiredTools + tools)
        self.saveChatSession = saveChatSession

        provider = Provider.provider(for: llmType)
    }

    private func saveChatSession(chatSessionUUID: String, runUUID: String, iterationIndex: Int, messages: [Message], userInputRequest: UserInputRequest, toolCallIndex: Int = 0, toolCalls: [ToolCall]?) {
        let suspendData = ChatSuspendData(
            chatSessionUUID: chatSessionUUID,
            agentUUID: uuid,
            runUUID: runUUID,
            iterationIndex: 0,
            messages: messages,
            userInputRequest: userInputRequest,
            toolCalls: toolCalls,
            toolCallIndex: toolCallIndex
        )
        saveChatSession(suspendData)
    }
    
    func getHistory() -> [Message] {
        return history
    }

    func trimMessages(_ messages: [Message], recentWindow: Int = 200) -> [Message] {
        // TODO: Recent-window trimming is brute-force, will need to change handling
        let systemMessages = messages.filter { $0.role == MsgSource.system.name }
        let nonSystemMessages = messages.filter { $0.role != MsgSource.system.name }
        let trimmed = nonSystemMessages.suffix(recentWindow)
        return (systemMessages + trimmed)
    }
    
    func executeTool(_ toolCall: ToolCall, chatSession: ChatSessionInfo) async -> String {
        guard let tool = tools.first(where: { $0.name == toolCall.name }) else {
            return "Error: unknown tool '\(toolCall.name)'"
        }

        return await tool.execute(args: toolCall.argDict)
    }

    func runTool(_ toolCall: ToolCall, chatSession: ChatSessionInfo) async -> ToolResult {
        guard let tool = tools.first(where: { $0.name == toolCall.name }) else {
            return .denied("Error: unknown tool '\(toolCall.name)'")
        }
        
        if toolCall.name == RequestUserInput().name {
            let prompt = toolCall.argDict["prompt"] as? String ?? "Input required"

            let request = UserInputRequest(
                uuid: UUID().uuidString,
                type: .input,
                prompt: prompt,
                toolCallName: toolCall.name,
                metadata: [:]
            )

            return .suspended(request)
        }
        
        if let permissionTool = tool as? PermissionAware {
            let requests = permissionTool.permissionRequests(args: toolCall.argDict)
            let evaluations = chatSession.mode.evaluateRequests(requests, session: chatSession)
            
            for evaluation in evaluations {
                switch evaluation.decision {
                case .allowed:
                    continue
                    
                case .denied(let reason):
                    return .denied("Permission denied: \(reason)")
                    
                case .requiresApproval(let reason):
                    let request = UserInputRequest(
                        uuid: UUID().uuidString,
                        type: .permission,
                        prompt: reason,
                        toolCallName: toolCall.name,
                        metadata: [:]
                    )
                    return .suspended(request)
                }
            }
        }
        return .completed(await tool.execute(args: toolCall.argDict))
    }

    func runAgent(
        userPrompt: String,
        systemPrompt: String = "",
        useThinking: Bool = true,
        chatSession: ChatSessionInfo,
        onEvent: ((_ event: AgentEvent, _ runUUID: String) -> Void)? = nil
    ) async -> (error: String?, messages: [Message]) {
        let runUUID = UUID().uuidString // Represents a specific prompt-response to allow piecing together chunks of a specific response into single text by clients
        var newMessages: [Message] = []

        if (!systemPrompt.isEmpty) {
            newMessages.append(Message(role: MsgSource.system.name, text: systemPrompt))
        }

        let context = MempalaceMemory.shared.getPromptContext(query: userPrompt)
        newMessages.append(Message(role: MsgSource.assistant.name, text: context))
        newMessages.append(Message(role: MsgSource.user.name, text: userPrompt))

        return await runInternalLoop(
            runUUID: runUUID,
            startMessages: newMessages,
            chatSession: chatSession,
            useThinking: useThinking,
            onEvent: onEvent
        )
    }
    
    func resumeAgent(
        chatSession: ChatSessionInfo,
        userResponse: UserInputResponse,
        onEvent: ((_ event: AgentEvent, _ runUUID: String) -> Void)? = nil
    ) async -> (error: String?, messages: [Message]) {
        guard let suspendData = chatSession.suspendData else {
            return ("No suspended session.", [])
        }
        guard let request = suspendData.userInputRequest else {
            return ("No pending request.", [])
        }
        guard (request.uuid == userResponse.requestUUID) else {
            return ("Request UUID mismatch.", [])
        }

        var messages = suspendData.messages
        let toolCalls = suspendData.toolCalls
        var toolCallIndex = suspendData.toolCallIndex
        
        if (userResponse.accepted == false) {
            messages.append(Message(role: MsgSource.tool.name, text: "User denied request."))
        } else {
            guard let toolCalls = suspendData.toolCalls else {
                return ("Missing tool calls.", messages)
            }
            if (toolCalls.indices.contains(suspendData.toolCallIndex)) {
                // Need to execute original tool that requested user-input (to prevent re-triggering request)
                let tc = toolCalls[suspendData.toolCallIndex]
                let toolOutput = await executeTool(tc, chatSession: chatSession)
                messages.append(Message(role: MsgSource.tool.name, text: toolOutput))
                
                toolCallIndex = (suspendData.toolCallIndex + 1)
            }
        }

        return await runInternalLoop(
            runUUID: suspendData.runUUID,
            iterationIndex: suspendData.iterationIndex,
            startMessages: messages,
            existingToolCalls: toolCalls,
            existingToolCallIndex: toolCallIndex,
            chatSession: chatSession,
            onEvent: onEvent
        )
    }
    
    func runInternalLoop(
        runUUID: String,
        iterationIndex: Int = 0,
        startMessages: [Message],
        existingToolCalls: [ToolCall]? = nil,
        existingToolCallIndex: Int = 0,
        chatSession: ChatSessionInfo,
        useThinking: Bool = true,
        onEvent: ((_ event: AgentEvent, _ runUUID: String) -> Void)? = nil
    ) async -> (error: String?, messages: [Message]) {
        var newMessages = startMessages
        
        let trimmedSessionHistory = trimMessages(history)
        var iterations = iterationIndex
        let modeIterations = chatSession.mode.iterationLimit ?? Int.max
        
        var pendingToolCalls = existingToolCalls
        var pendingToolIndex = existingToolCallIndex
        
        while iterations < modeIterations {
            if let existingToolCalls = pendingToolCalls {
                var toolResults: [Message] = []
                for index in pendingToolIndex..<existingToolCalls.count {
                    let tc = existingToolCalls[index]

                    print("Calling tool: \(tc.name)...")
                    onEvent?(.toolCall(tc.name), runUUID)
                    let result = await runTool(tc, chatSession: chatSession)

                    switch result {
                    case .completed(let output):
                        onEvent?(.toolResult(output), runUUID)
                        toolResults.append(Message(role: MsgSource.tool.name, text: output))
                        print("Tool result: completed.")

                    case .denied(let reason):
                        let text = "Permission denied: \(reason)"
                        onEvent?(.toolResult(text), runUUID)
                        toolResults.append(Message(role: MsgSource.tool.name, text: text))
                        print("Tool result: denied -> \(reason)")

                    case .suspended(let request):
                        onEvent?(.userInputRequest(request), runUUID)
                        print("Tool result: requirest permission -> \(request.prompt)")
                        newMessages.append(contentsOf: toolResults)
                        saveChatSession(chatSessionUUID: chatSession.uuid, runUUID: runUUID, iterationIndex: iterations, messages: newMessages, userInputRequest: request, toolCallIndex: index, toolCalls: existingToolCalls)
                        return (nil, newMessages)
                    }
                }

                newMessages.append(contentsOf: toolResults)
                pendingToolCalls = nil
                pendingToolIndex = 0
                
                iterations += 1
                continue
            }

            let promptMessage = (trimmedSessionHistory + newMessages)

            let response = await provider.send(
                messages: promptMessage,
                model: model,
                tools: tools,
                useThinking: useThinking,
                onUpdate: { response in
                    if !response.thinking.isEmpty {
                        onEvent?(.thinking(response.thinking), runUUID)
                    }
                    if !response.content.isEmpty {
                        onEvent?(.content(response.content), runUUID)
                    }
                }
            )
            let responseMsg = Message.fromProvider(response)
            newMessages.append(responseMsg)

            // No tools → final response
            guard let toolCalls = responseMsg.toolCalls,
                  (!toolCalls.isEmpty) else {
                history.append(contentsOf: newMessages)
                MempalaceMemory.shared.addConvHistory(messages: newMessages, agent: type)
                return (nil, newMessages)
            }

            pendingToolCalls = toolCalls
            pendingToolIndex = 0
        }

        if (iterations >= modeIterations) {
            let iterationMaxMsg = Message(role: MsgSource.assistant.name, text: "Reached main agent loop iteration limit, may not have completed tasks/tool-calls.")
            newMessages.append(iterationMaxMsg)
        }
        return ("Iteration limit reached.", newMessages)
    }
    
}

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

actor AgentRunner {
    private var running = false
    
    func setRunning(_ running: Bool = true) {
        self.running = running
    }
    
    func isRunning() -> Bool {
        return running
    }
}


class Agent {
    static let primaryAgentUUID = "PRIMARY"
    
    let uuid: String
    let userUUID: String
    let llmType: LLMClient.LLMType
    let type: AgentType
    var mode: ModeType
    let model: String
    var maxMessages: Int
    var tools: [Tool]
    
    private var history: [Message] = []
    var suspendData: SuspendData? = nil
    var directories: [String] = [DAWSON.root]
    
    var provider: LLMProvider
    let runner: AgentRunner

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
        userUUID: String,
        llmType: LLMClient.LLMType = .ollama,
        type: AgentType,
        mode: ModeType,
        model: String,
        maxMessages: Int,
        history: [Message] = [],
        tools: [Tool] = []
    ) {
        self.uuid = uuid
        self.userUUID = userUUID
        self.llmType = llmType
        self.type = type
        self.mode = mode
        self.model = model
        self.maxMessages = maxMessages
        self.history = history
        self.tools = (Agent.requiredTools + tools)

        provider = Provider.provider(for: llmType)
        runner = AgentRunner()
    }
    
    func getHistory() -> [Message] {
        return history
    }
    
    private func suspendSession(
        runUUID: String,
        iterationIndex: Int,
        messages: [Message],
        userInputRequest: UserInputRequest,
        toolCallIndex: Int = 0,
        toolCalls: [ToolCall]?
    ) {
        suspendData = SuspendData(
            runUUID: runUUID,
            iterationIndex: iterationIndex,
            messages: messages,
            userInputRequest: userInputRequest,
            toolCalls: toolCalls,
            toolCallIndex: toolCallIndex
        )
        // TODO: Need to send out Notification
    }

    private func trimMessages(_ messages: [Message]) -> [Message] {
        // TODO: Recent-window trimming is brute-force, will need to change handling
        let systemMessages = messages.filter { $0.role == MsgSource.system.name }
        let nonSystemMessages = messages.filter { $0.role != MsgSource.system.name }
        let trimmed = nonSystemMessages.suffix(maxMessages)
        return (systemMessages + trimmed)
    }
    
    private func executeTool(_ toolCall: ToolCall) async -> String {
        guard let tool = tools.first(where: { $0.name == toolCall.name }) else {
            return "Error: unknown tool '\(toolCall.name)'"
        }

        return await tool.execute(args: toolCall.argDict)
    }

    private func runTool(_ toolCall: ToolCall) async -> ToolResult {
        guard let tool = tools.first(where: { $0.name == toolCall.name }) else {
            return .denied("Error: unknown tool '\(toolCall.name)'")
        }
        
        if toolCall.name == RequestUserInput().name {
            let prompt = toolCall.argDict["prompt"] as? String ?? "Input required"

            let request = UserInputRequest(
                agentUUID: uuid,
                userUUID: userUUID,
                type: .input,
                prompt: prompt,
                toolCallName: toolCall.name,
                metadata: [:]
            )
            return .suspended(request)
        }
        
        if let permissionTool = tool as? PermissionAware {
            let requests = permissionTool.permissionRequests(args: toolCall.argDict)
            let evaluations = mode.evaluateRequests(requests, agent: self)
            
            for evaluation in evaluations {
                switch evaluation.decision {
                case .allowed:
                    continue
                    
                case .denied(let reason):
                    return .denied("Permission denied: \(reason)")
                    
                case .requiresApproval(let reason):
                    let request = UserInputRequest(
                        agentUUID: uuid,
                        userUUID: userUUID,
                        type: .permission,
                        prompt: reason,
                        toolCallName: toolCall.name,
                        metadata: [:]
                    )
                    return .suspended(request)
                }
            }
        } else if let chatTool = tool as? ChatAware {
            chatTool.setChat(DAWSON.shared.getChatForAgent(uuid))
        }
        return .completed(await tool.execute(args: toolCall.argDict))
    }

    func runAgent(
        userPrompt: String,
        systemPrompt: String = "",
        useThinking: Bool = true,
        onEvent: ((_ event: AgentEvent, _ runUUID: String) -> Void)? = nil
    ) async throws -> [Message] {
        if await (runner.isRunning()) { throw AgentError.agentRunning }
        await runner.setRunning()
        
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
            useThinking: useThinking,
            onEvent: onEvent
        )
    }
    
    func resumeAgent(
        userResponse: UserInputResponse,
        onEvent: ((_ event: AgentEvent, _ runUUID: String) -> Void)? = nil
    ) async throws -> [Message] {
        if await (runner.isRunning()) { throw AgentError.agentRunning }
        await runner.setRunning()
        
        guard let suspendData = suspendData else {
            throw AgentError.notSuspended
        }

        var messages = suspendData.messages
        let toolCalls = suspendData.toolCalls
        var toolCallIndex = suspendData.toolCallIndex
        
        if (userResponse.accepted == false) {
            messages.append(Message(role: MsgSource.tool.name, text: "User denied request."))
        } else {
            guard let toolCalls = suspendData.toolCalls else {
                throw AgentError.suspendMissingToolCalls
            }
            if (toolCalls.indices.contains(suspendData.toolCallIndex)) {
                // Need to execute original tool that requested user-input (to prevent re-triggering request)
                let tc = toolCalls[suspendData.toolCallIndex]
                if (tc.name != RequestUserInput().name) {
                    let toolOutput = await executeTool(tc)
                    messages.append(Message(role: MsgSource.tool.name, text: toolOutput))
                } else {
                    let toolOutput = "User responded to request: '\(userResponse)'."
                    messages.append(Message(role: MsgSource.tool.name, text: toolOutput))
                }
                
                toolCallIndex = (suspendData.toolCallIndex + 1)
            }
        }

        return await runInternalLoop(
            runUUID: suspendData.runUUID,
            iterationIndex: suspendData.iterationIndex,
            startMessages: messages,
            existingToolCalls: toolCalls,
            existingToolCallIndex: toolCallIndex,
            onEvent: onEvent
        )
    }
    
    func runInternalLoop(
        runUUID: String,
        iterationIndex: Int = 0,
        startMessages: [Message],
        existingToolCalls: [ToolCall]? = nil,
        existingToolCallIndex: Int = 0,
        useThinking: Bool = true,
        onEvent: ((_ event: AgentEvent, _ runUUID: String) -> Void)? = nil
    ) async -> [Message] {
        var newMessages = startMessages
        
        let trimmedSessionHistory = trimMessages(history)
        var iterations = iterationIndex
        let modeIterations = mode.iterationLimit ?? Int.max
        
        var pendingToolCalls = existingToolCalls
        var pendingToolIndex = existingToolCallIndex
        
        while iterations < modeIterations {
            if let existingToolCalls = pendingToolCalls {
                var toolResults: [Message] = []
                for index in pendingToolIndex..<existingToolCalls.count {
                    let tc = existingToolCalls[index]

                    print("Calling tool: \(tc.name)...")
                    onEvent?(.toolCall(tc.name), runUUID)
                    let result = await runTool(tc)

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
                        toolResults.append(Message(role: MsgSource.tool.name, text: "__PENDING_USER_INPUT__"))
                        newMessages.append(contentsOf: toolResults)
                        suspendSession(runUUID: runUUID, iterationIndex: iterations, messages: newMessages, userInputRequest: request, toolCallIndex: index, toolCalls: existingToolCalls)
                        return newMessages
                    }
                }

                newMessages.append(contentsOf: toolResults)
                pendingToolCalls = nil
                pendingToolIndex = 0
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
                return newMessages
            }

            pendingToolCalls = toolCalls
            pendingToolIndex = 0
            iterations += 1
        }

        if (iterations >= modeIterations) {
            let iterationMaxMsg = Message(role: MsgSource.assistant.name, text: "Reached main agent loop iteration limit, may not have completed tasks/tool-calls.")
            newMessages.append(iterationMaxMsg)
        }
        return newMessages
    }
    
}

extension Agent {
    struct SuspendData: Codable {
        let runUUID: String
        var iterationIndex: Int
        var messages: [Message]
        var userInputRequest: UserInputRequest? = nil
        var toolCalls: [ToolCall]? = nil
        var toolCallIndex: Int = 0
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
    
    enum AgentError: Error, LocalizedError {
        case agentRunning
        case notSuspended
        case noUserInputRequest
        case suspendMissingToolCalls
        
        var errorDescription: String? {
            switch self {
            case .agentRunning:
                return "Agent already running"
            case .notSuspended:
                return "Agent not suspended, can't be resumed"
            case .noUserInputRequest:
                return "Agent suspended but no UserInputRequest"
            case .suspendMissingToolCalls:
                return "Agent suspended but missing tool calls"
            }
        }
    }
}

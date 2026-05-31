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


class Agent: Codable {
    let uuid: String
    let userUUID: String
    let llmType: LLMClient.LLMType
    let type: AgentType
    var mode: ModeType
    let model: String
    var maxMessages: Int
    var updatedTimestamp: Int64
    
    private var tools: [Tool] = (Agent.requiredTools + Agent.optionalTools)
    private var history: [Message] = []
    var suspendData: SuspendData? = nil
    var directories: [String] = [DAWSON.root]
    
    var provider: LLMProvider
    let runner: AgentRunner

    static let agentsDirectory = (DAWSON.workspace).appendingPathComponent("agents")
    
    static var optionalTools: [Tool] {
        return [WriteFile(), SearchFile(), PatchFile(), ReplaceInFile(), ReadFile(), ListFiles(), Speak(), SelfConfig(), RichFormatter()]
    }
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
        updatedTimestamp: Int64 = Int64(Date.now.timeIntervalSince1970)
    ) {
        self.uuid = uuid
        self.userUUID = userUUID
        self.llmType = llmType
        self.type = type
        self.mode = mode
        self.model = model
        self.maxMessages = maxMessages
        self.updatedTimestamp = updatedTimestamp
        
        tools.append(contentsOf: tools)
        provider = Provider.provider(for: llmType)
        runner = AgentRunner()
    }
    
    enum CodingKeys: String, CodingKey {
        case uuid
        case userUUID
        case llmType
        case type
        case mode
        case model
        case maxMessages
        case updatedTimestamp
        // TODO: Need to add tools later
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        uuid = try container.decode(String.self, forKey: .uuid)
        userUUID = try container.decode(String.self, forKey: .userUUID)
        llmType = try container.decode(LLMClient.LLMType.self, forKey: .llmType)
        type = try container.decode(AgentType.self, forKey: .type)
        mode = try container.decode(ModeType.self, forKey: .mode)
        model = try container.decode(String.self, forKey: .model)
        maxMessages = try container.decode(Int.self, forKey: .maxMessages)
        updatedTimestamp = try container.decode(Int64.self, forKey: .updatedTimestamp)
        
        provider = Provider.provider(for: llmType)
        runner = AgentRunner()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(uuid, forKey: .uuid)
        try container.encode(userUUID, forKey: .userUUID)
        try container.encode(llmType, forKey: .llmType)
        try container.encode(type, forKey: .type)
        try container.encode(mode, forKey: .mode)
        try container.encode(model, forKey: .model)
        try container.encode(maxMessages, forKey: .maxMessages)
        // TODO: Need to add tools later
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
                    return .denied(reason)
                    
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
            newMessages.append(Message(runUUID: runUUID, role: MsgSource.system.name, text: systemPrompt))
        }

        // SKIPPING FORCED CONTEXT GRAB FOR FURTHER TESTING
//        let context = MempalaceMemory.shared.getPromptContext(query: userPrompt)
//        newMessages.append(Message(runUUID: runUUID, role: MsgSource.assistant.name, text: context))
        newMessages.append(Message(runUUID: runUUID, role: MsgSource.user.name, text: userPrompt))

        let loopMessages = await runInternalLoop(
            runUUID: runUUID,
            startMessages: newMessages,
            useThinking: useThinking,
            onEvent: onEvent
        )
        await runner.setRunning(false)
        try? appendMessages(loopMessages, agentUUID: uuid)
        return loopMessages
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
            messages.append(Message(runUUID: suspendData.runUUID, role: MsgSource.tool.name, text: "User denied request."))
        } else {
            guard let toolCalls = suspendData.toolCalls else {
                throw AgentError.suspendMissingToolCalls
            }
            if (toolCalls.indices.contains(suspendData.toolCallIndex)) {
                // Need to execute original tool that requested user-input (to prevent re-triggering request)
                let tc = toolCalls[suspendData.toolCallIndex]
                if (tc.name != RequestUserInput().name) {
                    let toolOutput = await executeTool(tc)
                    messages.append(Message(runUUID: suspendData.runUUID, role: MsgSource.tool.name, text: toolOutput))
                } else {
                    let toolOutput = "User responded to request: '\(userResponse)'."
                    messages.append(Message(runUUID: suspendData.runUUID, role: MsgSource.tool.name, text: toolOutput))
                }
                
                toolCallIndex = (suspendData.toolCallIndex + 1)
            }
        }

        let loopMessages = await runInternalLoop(
            runUUID: suspendData.runUUID,
            iterationIndex: suspendData.iterationIndex,
            startMessages: messages,
            existingToolCalls: toolCalls,
            existingToolCallIndex: toolCallIndex,
            onEvent: onEvent
        )
        await runner.setRunning(false)
        try? appendMessages(loopMessages, agentUUID: uuid)
        return loopMessages
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
                        toolResults.append(Message(runUUID: runUUID, role: MsgSource.tool.name, text: output))
                        print("Tool result: completed.")

                    case .denied(let reason):
                        onEvent?(.toolResult(reason), runUUID)
                        toolResults.append(Message(runUUID: runUUID, role: MsgSource.tool.name, text: reason))
                        print("Tool result: denied -> \(reason)")

                    case .suspended(let request):
                        onEvent?(.userInputRequest(request), runUUID)
                        print("Tool result: requirest permission -> \(request.prompt)")
                        toolResults.append(Message(runUUID: runUUID, role: MsgSource.tool.name, text: "__PENDING_USER_INPUT__"))
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
            let responseMsg = Message.fromProvider(response, runUUID: runUUID)
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
            let iterationMaxMsg = Message(runUUID: runUUID, role: MsgSource.assistant.name, text: "Reached main agent loop iteration limit, may not have completed tasks/tool-calls.")
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
    
    enum AgentType: Codable {
        case dawson
        case squireBot
        case page
        
        var name: String {
            switch (self) {
            case .dawson:
                "agent_dawson"
            case .squireBot:
                "agent_squirebot"
            case .page:
                "agent_page"
            }
        }
        
        var soulPath: String? {
            switch (self) {
            case .dawson:
                "/workspace/config/DAWSON_SOUL.md"
            case .squireBot:
                "/workspace/config/SQUIREBOT_SOUL.md"
            case .page:
                nil
            }
        }
        
        static func fromName(_ name: String) -> AgentType? {
            switch name {
            case self.dawson.name:
                return .dawson
            case self.squireBot.name:
                return .squireBot
            case self.page.name:
                return .page
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

extension Agent {
    static func loadAllAgents() -> [Agent] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: agentsDirectory, includingPropertiesForKeys: nil) else { return [] }

        var agents: [Agent] = []
        for fileURL in files {
            guard (fileURL.pathExtension == "json"),
                  let data = try? Data(contentsOf: fileURL),
                  let agent = try? JSONDecoder().decode(Agent.self, from: data) else { continue }
            
            agent.history = loadHistory(agentUUID: agent.uuid)
            agents.append(agent)
        }
        
        return agents.sorted { ($0.history.last?.createdAt.timeIntervalSince1970 ?? 0) > ($1.history.last?.createdAt.timeIntervalSince1970 ?? 0) }
    }
    
    static func loadAgent(agentUUID: String) -> Agent? {
        let url = metadataURL(agentUUID: agentUUID)
        guard let data = try? Data(contentsOf: url),
              let agent = try? JSONDecoder().decode(Agent.self, from: data) else { return nil }
        
        agent.history = loadHistory(agentUUID: agentUUID)
        return agent
    }
    
    static func loadHistory(agentUUID: String) -> [Message] {
        let fileURL = historyURL(agentUUID: agentUUID)
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return contents
            .split(separator: "\n")
            .compactMap { line in
                guard let data = line.data(using: .utf8) else { return nil }
                return try? decoder.decode(Message.self, from: data)
            }
    }
    
    func saveMetadata() {
        do {
            try FileManager.default.createDirectory(at: Agent.agentsDirectory, withIntermediateDirectories: true)
            
            let data = try JSONEncoder().encode(self)
            try data.write(to: Agent.metadataURL(agentUUID: uuid), options: .atomic)
            print("Successfully saved Agent \(uuid) metadata")
        } catch {
            print("Failed to save Agent \(uuid) metadata: ", error)
        }
    }
    
    private static func metadataURL(agentUUID: String) -> URL {
        return Agent.agentsDirectory.appendingPathComponent("metadata_\(agentUUID).json")
    }

    private static func historyURL(agentUUID: String) -> URL {
        return Agent.agentsDirectory.appendingPathComponent("history_\(agentUUID).jsonl")
    }
    
    private func appendMessages(_ messages: [Message], agentUUID: String) throws {
        let fileURL = Agent.historyURL(agentUUID: agentUUID)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        
        for message in messages {
            let jsonData = try encoder.encode(message)
            handle.write(jsonData)
            handle.write(Data("\n".utf8))
        }
    }
    
    private func appendMessage(_ message: Message, agentUUID: String) throws {
        try appendMessages([message], agentUUID: agentUUID)
    }
}

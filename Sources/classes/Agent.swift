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
    let type: AgentType
    var mode: ModeType
    var model: LLMModel
    var state: AgentState
    var thoughtWindow: Int
    var contextWindow: Int32
    var useThinking: Bool
    var directories: [String]
    var updatedTimestamp: Int64
    
    private var tools: [Tool] = (Agent.requiredTools + Agent.optionalTools)
    private var history: [Message] = []
    private var summary: String = ""
    var suspendData: SuspendData? = nil
    
    var provider: LLMProvider
    let runner: AgentRunner

    static let agentsDirectory = DAWSON.workspace.appendingPathComponent("agents")
    
    static var optionalTools: [Tool] {
        return [WriteFile(), SearchFile(), PatchFile(), ReplaceInFile(), ReadFile(), ListFiles(), Speak(), RichFormatter()]
    }
    static var requiredTools: [Tool] {
        [RequestUserInput(), EnvAwareness(), GetFullSkill(), GetSessionInfo()] + Agent.memoryTools
    }
    static var memoryTools: [Tool] {
        [
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
        providerType: ProviderClient.ProviderType = .ollama,
        type: AgentType,
        mode: ModeType,
        model: LLMModel,
        state: AgentState = .ready,
        thoughtWindow: Int,
        contextWindow: Int32,
        useThinking: Bool = true,
        directories: [String] = [DAWSON.root.path],
        updatedTimestamp: Int64 = Int64(Date.now.timeIntervalSince1970)
    ) {
        self.uuid = uuid
        self.userUUID = userUUID
        self.type = type
        self.mode = mode
        self.model = model
        self.state = state
        self.thoughtWindow = thoughtWindow
        self.contextWindow = contextWindow
        self.useThinking = useThinking
        self.directories = directories
        self.updatedTimestamp = updatedTimestamp
        
        provider = Provider.provider(for: model.provider)
        runner = AgentRunner()
    }
    
    enum CodingKeys: String, CodingKey {
        case uuid
        case userUUID
        case type
        case mode
        case model
        case state
        case thoughtWindow
        case contextWindow
        case useThinking
        case directories
        case updatedTimestamp
        // TODO: Need to add tools later
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        uuid = try container.decode(String.self, forKey: .uuid)
        userUUID = try container.decode(String.self, forKey: .userUUID)
        type = try container.decode(AgentType.self, forKey: .type)
        mode = try container.decode(ModeType.self, forKey: .mode)
        model = try container.decode(LLMModel.self, forKey: .model)
        state = try container.decode(AgentState.self, forKey: .state)
        thoughtWindow = try container.decode(Int.self, forKey: .thoughtWindow)
        contextWindow = try container.decode(Int32.self, forKey: .contextWindow)
        useThinking = try container.decode(Bool.self, forKey: .useThinking)
        directories = try container.decode([String].self, forKey: .directories)
        updatedTimestamp = try container.decode(Int64.self, forKey: .updatedTimestamp)
        
        provider = Provider.provider(for: model.provider)
        runner = AgentRunner()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(uuid, forKey: .uuid)
        try container.encode(userUUID, forKey: .userUUID)
        try container.encode(type, forKey: .type)
        try container.encode(mode, forKey: .mode)
        try container.encode(model, forKey: .model)
        try container.encode(state, forKey: .state)
        try container.encode(thoughtWindow, forKey: .thoughtWindow)
        try container.encode(contextWindow, forKey: .contextWindow)
        try container.encode(useThinking, forKey: .useThinking)
        try container.encode(directories, forKey: .directories)
        try container.encode(updatedTimestamp, forKey: .updatedTimestamp)
        // TODO: Need to add tools later
    }
    
    func getHistory() -> [Message] {
        return history
    }
    
    func getSummary() -> String {
        return summary
    }
    
    private func suspendSession(
        runUUID: String,
        iterationIndex: Int,
        messages: [Message],
        userInputRequest: UserInputRequest,
        toolCalls: [ToolCall] = [],
        toolCallIndex: Int = 0
    ) {
        suspendData = SuspendData(
            runUUID: runUUID,
            iterationIndex: iterationIndex,
            messages: messages,
            userInputRequest: userInputRequest,
            toolCalls: toolCalls,
            toolCallIndex: toolCallIndex
        )
    }

    private func trimMessages(_ messages: [Message]) -> [Message] {
        // TODO: Recent-window trimming is brute-force, will need to change handling
        let systemMessages = messages.filter { $0.role == MsgSource.system.name }
        let nonSystemMessages = messages.filter { $0.role != MsgSource.system.name }
        let trimmed = nonSystemMessages.suffix(thoughtWindow)
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
        runUUID: String,
        userPrompt: String,
        systemPrompt: String = "",
        onEvent: ((_ event: AgentEvent, _ runUUID: String) -> Void)? = nil
    ) async throws -> [Message] {
        if await (runner.isRunning()) { throw AgentError.agentRunning }
        await runner.setRunning()
        
        // In case previously stuck in .awaitingInput, if calling runAgent() then suspend-state no longer valid
        self.suspendData = nil
        self.state = .ready
        
        var newMessages: [Message] = []

        if (!systemPrompt.isEmpty) {
            newMessages.append(Message(runUUID: runUUID, role: MsgSource.system.name, text: systemPrompt))
        }

        newMessages.append(Message(runUUID: runUUID, role: MsgSource.user.name, text: userPrompt))

        let loopMessages = await runInternalLoop(
            runUUID: runUUID,
            startMessages: newMessages,
            onEvent: onEvent
        )
        
        if (self.state != .awaitingInput) {
            await runMemorySessionSummarizer(
                runUUID: runUUID,
                messages: loopMessages,
                onEvent: onEvent
            )
        }
        
        await setSummary()
        saveMessagesToHistory(loopMessages, agentUUID: uuid)
        saveMetadata()
        await runner.setRunning(false)
        return loopMessages
    }
    
    func resumeAgent(
        userResponse: UserInputResponse,
        onEvent: ((_ event: AgentEvent, _ runUUID: String) -> Void)? = nil
    ) async throws -> [Message] {
        if await (runner.isRunning()) { throw AgentError.agentRunning }
        await runner.setRunning()
        
        guard let suspendData = suspendData else {
            await runner.setRunning(false)
            throw AgentError.notSuspended
        }
        

        let runUUID = suspendData.runUUID
        let request = suspendData.userInputRequest
        var messages = suspendData.messages
        let toolCalls = suspendData.toolCalls
        var tcIndex = suspendData.toolCallIndex
        
        switch request.type {
        case .permission:
            if let accepted = userResponse.accepted,
               (accepted) {
                if (toolCalls.indices.contains(tcIndex)) {
                    // Need to execute original tool that requested permission (to prevent re-triggering request)
                    let tc = toolCalls[tcIndex]
                    let toolOutput = await executeTool(tc)
                    messages.append(Message(runUUID: runUUID, role: MsgSource.tool.name, text: AgentUtilities.userInputText(request: request, response: userResponse)))
                    messages.append(Message(runUUID: runUUID, role: MsgSource.tool.name, text: toolOutput))
                }
            } else {
                messages.append(Message(runUUID: runUUID, role: MsgSource.tool.name, text: AgentUtilities.userInputText(request: request, response: userResponse)))
            }
        case .confirmation:
            // Currently just inputs back into LLM, in future can be used for specific, binary requirements (not just approve/deny)
            messages.append(Message(runUUID: runUUID, role: MsgSource.tool.name, text: AgentUtilities.userInputText(request: request, response: userResponse)))
        case .input:
            messages.append(Message(runUUID: runUUID, role: MsgSource.tool.name, text: AgentUtilities.userInputText(request: request, response: userResponse)))
        }
        
        // Tool permission/input handled and tool executed (or not)
        tcIndex += 1
        self.suspendData = nil
        self.state = .ready

        let loopMessages = await runInternalLoop(
            runUUID: suspendData.runUUID,
            iterationIndex: suspendData.iterationIndex,
            startMessages: messages,
            existingToolCalls: toolCalls,
            existingToolCallIndex: tcIndex,
            onEvent: onEvent
        )
        
        if (self.state != .awaitingInput) {
            await runMemorySessionSummarizer(
                runUUID: runUUID,
                messages: loopMessages,
                onEvent: onEvent
            )
        }
            
        saveMessagesToHistory(loopMessages, agentUUID: self.uuid)
        saveMetadata()
        await runner.setRunning(false)
        return loopMessages
    }
    
    private func runInternalLoop(
        runUUID: String,
        iterationIndex: Int = 0,
        startMessages: [Message],
        existingToolCalls: [ToolCall] = [],
        existingToolCallIndex: Int = 0,
        onEvent: ((_ event: AgentEvent, _ runUUID: String) -> Void)? = nil
    ) async -> [Message] {
        var newMessages = startMessages
        
        let trimmedHistory = trimMessages(history)
        let modeIterations = mode.iterationLimit ?? Int.max
        
        // Begins with last session data (if resuming a supension)
        var iterations = iterationIndex
        var pendingToolCalls = existingToolCalls
        var pendingToolIndex = existingToolCallIndex
        
        while iterations < modeIterations {
            var toolResults: [Message] = []
            for index in pendingToolIndex..<pendingToolCalls.count {
                let tc = pendingToolCalls[index]

                print("Calling tool: \(tc.name)...")
                onEvent?(.toolCall(tc.name), runUUID)
                toolResults.append(Message(runUUID: runUUID, role: MsgSource.tool.name, text: "CALLING TOOL: '\(tc.name)'"))
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
                    if (!request.prompt.isEmpty) {
                        onEvent?(.content(request.prompt), runUUID)
                        toolResults.append(Message(runUUID: runUUID, role: MsgSource.assistant.name, text: request.prompt))
                    }
                    print("Tool result: permission -> \(request.prompt)")
                    newMessages.append(contentsOf: toolResults)
                    suspendSession(runUUID: runUUID, iterationIndex: iterations, messages: newMessages, userInputRequest: request, toolCalls: pendingToolCalls, toolCallIndex: index)
                    self.state = .awaitingInput
                    return newMessages
                }
            }
            newMessages.append(contentsOf: toolResults)

            let promptMessage = (trimmedHistory + newMessages)
            let response = await provider.send(
                messages: promptMessage,
                model: model,
                tools: tools,
                useThinking: useThinking,
                contextWindow: contextWindow,
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
                return newMessages
            }

            pendingToolCalls = toolCalls
            pendingToolIndex = 0
            iterations += 1
        }
        return newMessages
    }
    
    private func runMemorySessionSummarizer(
        runUUID: String,
        messages: [Message],
        onEvent: ((_ event: AgentEvent, _ runUUID: String) -> Void)? = nil
    ) async {
        var summarizerMessages = messages
        summarizerMessages.append(Message(runUUID: runUUID, role: MsgSource.system.name, text: AgentUtilities.memorySessionPrompt))

        let response = await provider.send(
            messages: summarizerMessages,
            model: model,       // Eventually change this to be subagent model (faster)
            tools: Agent.memoryTools,
            useThinking: useThinking,
            contextWindow: contextWindow,
            onUpdate: { _ in }
        )
        let responseMsg = Message.fromProvider(response, runUUID: runUUID)
        summarizerMessages.append(responseMsg)

        guard let toolCalls = responseMsg.toolCalls else {
            return
        }

        for tc in toolCalls {
            onEvent?(.toolCall(tc.name), runUUID)

            guard let tool = Agent.memoryTools.first(where: { $0.name == tc.name }) else { continue }

            let output = await tool.execute(args: tc.argDict)
            onEvent?(.toolResult(output), runUUID)

            summarizerMessages.append(Message(runUUID: runUUID, role: MsgSource.tool.name, text: output))
        }
    }
    
    private func setSummary() async {
        let runUUID = UUID().uuidString
        let recentMsgCnt = 50
        var messages: [Message] = history
            .filter { $0.role == MsgSource.user.name || $0.role == MsgSource.assistant.name }
            .suffix(recentMsgCnt)
        messages.append(Message(runUUID: runUUID, role: MsgSource.system.name, text: AgentUtilities.convSummaryPrompt))
        
        let response = await provider.send(
            messages: messages,
            model: model,       // Eventually change this to be subagent model (faster)
            tools: [],
            useThinking: useThinking,
            contextWindow: contextWindow,
            onUpdate: { _ in }
        )
        let responseMsg = Message.fromProvider(response, runUUID: runUUID)
        self.summary = responseMsg.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

extension Agent {
    struct SuspendData: Codable {
        let runUUID: String
        var iterationIndex: Int
        var messages: [Message]
        var userInputRequest: UserInputRequest
        var toolCalls: [ToolCall] = []
        var toolCallIndex: Int = 0
    }
    
    enum AgentState: String, Codable {
        case ready = "READY"
        case awaitingInput = "AWAITING_INPUT"
    }
    
    enum AgentType: String, Codable {
        case dawson = "DAWSON"
        case squireBot = "SQUIREBOT"
        case page = "PAGE"
        
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
                "config/DAWSON_SOUL.md"
            case .squireBot:
                "config/SQUIREBOT_SOUL.md"
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
        case invalidResponse
        
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
            case .invalidResponse:
                return "Agent suspended but user response invalid"
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
    
    func deleteAll() {
        let metaURL = Agent.metadataURL(agentUUID: uuid)
        let historyURL = Agent.historyURL(agentUUID: uuid)

        do {
            if FileManager.default.fileExists(atPath: metaURL.path) {
                try FileManager.default.removeItem(at: metaURL)
            }
            if FileManager.default.fileExists(atPath: historyURL.path) {
                try FileManager.default.removeItem(at: historyURL)
            }
            print("Successfully deleted Agent \(uuid) data")
        } catch {
            print("Failed to delete Agent \(uuid) data: ", error)
        }
    }
    
    private static func metadataURL(agentUUID: String) -> URL {
        return Agent.agentsDirectory.appendingPathComponent("metadata_\(agentUUID).json")
    }

    private static func historyURL(agentUUID: String) -> URL {
        return Agent.agentsDirectory.appendingPathComponent("history_\(agentUUID).jsonl")
    }
    
    private func saveMessagesToHistory(_ messages: [Message], agentUUID: String) {
        do {
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
        } catch {
            print("Failed to save Agent \(uuid) messages to history: ", error)
        }
    }
    
    private func appendMessage(_ message: Message, agentUUID: String) {
        saveMessagesToHistory([message], agentUUID: agentUUID)
    }
}

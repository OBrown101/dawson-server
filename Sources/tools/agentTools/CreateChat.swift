//
//  CreateChat.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/2/26.
//

import Foundation

class CreateChat: ChatAware, DelegationBubbleAware {
    static let name = "create_chat"

    private var chat: Chat?
    private var pending: PendingChildSuspension?
    private var stagedBubble: UserInputRequest?
    private var stagedResponse: UserInputResponse?

    func setChat(_ chat: Chat?) {
        self.chat = chat
    }

    var hasPendingUserResponse: Bool {
        (stagedResponse != nil)
    }

    func setUserResponse(_ response: UserInputResponse) {
        stagedResponse = response
    }

    func consumePendingBubble() -> UserInputRequest? {
        defer { stagedBubble = nil }
        return stagedBubble
    }

    func capturePendingState() -> PendingChildSuspension? {
        return pending
    }

    func restorePendingState(_ state: PendingChildSuspension?) {
        pending = state
    }

    func permissionRequests(args: [String: Any]) -> [PermissionRequest] {
        return [
            PermissionRequest(action: .delegate)
        ]
    }

    private let toolDescription = """
        Creates a new USER-OWNED Squirebot chat — one the user prompts \
        directly, not a worker of yours. Requires the user's approval, since \
        the chat keeps its granted mode independently of yours afterward. Mode \
        is clamped to at most your current mode and the workspace must be \
        within your own. Optionally (if user requests) seed it with initial context \
        you synthesize (e.g. knowledge merged from several existing chats — read \
        them first via \(TalkToAgent.name) or your own notes); the seed message \
        is attributed to you in the transcript. For a task worker you will \
        oversee yourself, use \(DelegateTask.name) instead.
        """

    private let parameterSchema: [String: Any] = [
        "type": "object",
        "required": ["title"],
        "properties": [
            "title": [
                "type": "string",
                "description": "Short chat title (2-6 words) the user will see"
            ],
            "initial_context": [
                "type": "string",
                "description": "Optional opening brief for the new chat: background, merged knowledge, goals. Written as if for a competent Squirebot with NO other context."
            ],
            "mode": [
                "type": "string",
                "enum": ModeType.allCases.map { $0.rawValue },
                "description": "Permission mode for the chat. Clamped to your own mode; defaults to your mode. Grant the least that is needed."
            ],
            "workspace_directories": [
                "type": "array",
                "items": ["type": "string"],
                "description": "Workspace for the chat; must be within your own workspace. Defaults to your full workspace. Grant the least that is needed."
            ]
        ]
    ]

    func openAISchema() -> [String: Any] {
        return [
            "type": "function",
            "name": CreateChat.name,
            "description": toolDescription,
            "parameters": parameterSchema
        ]
    }

    func anthropicSchema() -> [String: Any] {
        return [
            "name": CreateChat.name,
            "description": toolDescription,
            "input_schema": parameterSchema
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": CreateChat.name,
                "description": toolDescription,
                "parameters": parameterSchema
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let parentChat = chat,
              let parent = AgentHandler.shared.getAgent(parentChat.agentUUID) else {
            return "Error: No originating chat context."
        }

        // --- Resume leg: the user decided on the creation request ---
        if let pending = self.pending {
            guard let response = self.stagedResponse else {
                return "Error: Creation resume reached without a user decision."
            }
            self.stagedResponse = nil
            self.pending = nil

            switch pending.kind {
            case .chatCreation(let brief, let mode, let directories, let title):
                guard (response.accepted == true) else {
                    return "The user declined the creation of chat '\(title)'. Nothing was created."
                }
                return await createUserChat(
                    chatUUID: pending.childChatUUID,
                    agentUUID: pending.childAgentUUID,
                    parent: parent,
                    parentChat: parentChat,
                    title: title,
                    mode: mode,
                    directories: directories,
                    brief: brief
                )

            case .childRequest:
                // The seeded opening message raised a request that bubbled up.
                let step = await DelegationRunner.resumeChild(pending: pending, response: response, parentAgent: parent)
                return handle(step, taskTitle: pending.taskTitle)

            default:
                return "Error: Unexpected pending state for \(CreateChat.name)."
            }
        }

        // --- Fresh leg ---
        guard let title = args["title"] as? String, !title.isEmpty else {
            return "Error: Missing required parameter 'title'."
        }

        // Note: no live tether to parent once user-owned chat created
        let requestedMode = (args["mode"] as? String).flatMap(ModeType.fromName) ?? parent.effectiveMode
        let chatMode = ModeType.lower(of: requestedMode, parent.effectiveMode)

        let requestedDirs = (args["workspace_directories"] as? [String]) ?? parent.effectiveDirectories
        if let offender = DelegationRunner.validateWorkspaceSubset(requested: requestedDirs, parent: parent.effectiveDirectories) {
            return """
            Error: '\(offender)' is outside your own workspace; a chat you create \
            cannot be granted directories you do not hold. Your workspace: \
            \(parent.effectiveDirectories.joined(separator: ", ")). If access is \
            genuinely needed, ask the user to widen your workspace first.
            """
        }

        let brief = args["initial_context"] as? String

        let request = UserInputRequest(
            agentUUID: parent.uuid,
            userUUID: parent.userUUID,
            type: .confirmation,
            prompt: """
            Dawson requests to create a new chat for you: '\(title)'.

            Mode: \(chatMode)
            Workspace: \(requestedDirs.isEmpty ? "(none)" : requestedDirs.joined(separator: ", "))
            Seeded context: \((brief == nil) ? "none" : "yes (attributed to Dawson in the transcript)")

            Unlike his workers, this chat is YOURS: you prompt it directly, and \
            its mode stays as granted even if Dawson's mode later changes.
            """,
            toolCallName: CreateChat.name
        )
        self.pending = PendingChildSuspension(
            kind: .chatCreation(brief: brief, mode: chatMode, directories: requestedDirs, title: title),
            childChatUUID: UUID().uuidString,
            childAgentUUID: UUID().uuidString,
            taskTitle: title
        )
        self.stagedBubble = request
        return "(Awaiting the user's approval to create the chat.)"
    }

    private func createUserChat(
        chatUUID: String,
        agentUUID: String,
        parent: Agent,
        parentChat: Chat,
        title: String,
        mode: ModeType,
        directories: [String],
        brief: String?
    ) async -> String {
        // Re-clamp at execution time: Dawson's mode may have dropped while the
        // approval sat with the user. Creation can only preserve or shrink.
        let finalMode = ModeType.lower(of: mode, parent.effectiveMode)

        await DAWSON.shared.createSquireChat(chatUUID: chatUUID, userUUID: parentChat.userUUID, agentUUID: agentUUID)

        guard let newChat = DAWSON.shared.getChat(chatUUID),
              let newAgent = AgentHandler.shared.getAgent(agentUUID) else {
            return "Error: Failed to create the chat."
        }

        newChat.title = title
        newChat.saveMetadata()

        newAgent.mode = finalMode
        newAgent.directories = directories
        newAgent.parentAgentUUID = nil    // user-owned from birth
        newAgent.saveMetadata()
        DAWSON.shared.broadcastAgentUpsert(newAgent)

        guard let brief = brief,
              (!brief.isEmpty) else {
            return "Created user-owned chat '\(title)' (chat UUID: \(chatUUID)) at \(finalMode). It has no messages yet; the user can prompt it directly, or you can via \(TalkToAgent.name)."
        }

        // Seed the opening context through the normal delegation path so
        // originActor attribution holds ("⚔ Dawson (acting)").
        let message = "[Message from Dawson]\n\n" + brief
        let step = await DelegationRunner.begin(
            chat: newChat,
            childAgentUUID: agentUUID,
            parentAgent: parent,
            taskTitle: title,
            prompt: message
        )
        return handle(step, taskTitle: title)
    }

    private func handle(_ step: DelegationStep, taskTitle: String) -> String {
        switch step {
        case .completed(let outcome):
            return DelegationRunner.formatOutcome(outcome, taskTitle: taskTitle)

        case .needsUser(let request, let pendingState):
            self.pending = pendingState
            self.stagedBubble = request
            return "(Awaiting the user's decision on the new chat's request.)"
        }
    }
}

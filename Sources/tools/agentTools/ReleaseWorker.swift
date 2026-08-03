//
//  ReleaseWorker.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/2/26.
//

import Foundation

class ReleaseWorker: ChatAware, DelegationBubbleAware {
    static let name = "release_worker"

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
        Hands one of YOUR workers (created via \(DelegateTask.name)) over to the \
        user as a chat they own and prompt directly. Requires the user's \
        approval. On release the worker's capabilities are FROZEN at their \
        current effective values (mode and workspace as clamped to yours right \
        now) — release never expands what an agent can do. After release you \
        may still message the chat via \(TalkToAgent.name), but under user-owned \
        rules (approval needed if it later outranks you). Use this when a \
        worker's chat has lasting value to the user beyond its delegated task. \
        This is one-way: user chats can never be captured as workers.
        """

    private let parameterSchema: [String: Any] = [
        "type": "object",
        "required": ["chat_uuid"],
        "properties": [
            "chat_uuid": [
                "type": "string",
                "description": "UUID of YOUR worker's chat (from \(DelegateTask.name)'s report or \(ListAgents.name))"
            ],
            "reason": [
                "type": "string",
                "description": "One sentence for the user: why this chat is worth keeping"
            ]
        ]
    ]

    func openAISchema() -> [String: Any] {
        return [
            "type": "function",
            "name": ReleaseWorker.name,
            "description": toolDescription,
            "parameters": parameterSchema
        ]
    }

    func anthropicSchema() -> [String: Any] {
        return [
            "name": ReleaseWorker.name,
            "description": toolDescription,
            "input_schema": parameterSchema
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": ReleaseWorker.name,
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

        // --- Resume leg: the user decided on the release ---
        if let pending = self.pending {
            guard let response = self.stagedResponse else {
                return "Error: Release resume reached without a user decision."
            }
            self.stagedResponse = nil
            self.pending = nil

            guard case .workerRelease = pending.kind else {
                return "Error: Unexpected pending state for \(ReleaseWorker.name)."
            }
            guard (response.accepted == true) else {
                return "The user declined the release of '\(pending.taskTitle)'. It remains your worker."
            }
            return release(chatUUID: pending.childChatUUID, agentUUID: pending.childAgentUUID, parent: parent)
        }

        // --- Fresh leg ---
        guard let chatUUID = args["chat_uuid"] as? String, !chatUUID.isEmpty else {
            return "Error: Missing required parameter 'chat_uuid'."
        }

        guard let targetChat = DAWSON.shared.getChat(chatUUID) else {
            return "Error: No chat found with UUID '\(chatUUID)'. Use \(ListAgents.name) to see existing agents and their chats."
        }
        guard (targetChat.userUUID == parentChat.userUUID) else {
            return "Error: That chat belongs to a different user."
        }
        guard let target = AgentHandler.shared.getAgent(targetChat.agentUUID),
              (target.type == .squireBot) else {
            return "Error: \(ReleaseWorker.name) can only release Squirebots."
        }

        // Release is strictly worker -> user-owned, and only YOUR worker.
        guard (target.parentAgentUUID != nil) else {
            return "Error: '\(targetChat.title)' is already the user's own chat."
        }
        guard (target.parentAgentUUID == parent.uuid) else {
            return "Error: That Squirebot is operated by another agent and is not yours to release."
        }

        // Never release mid-flight: a running task or in-progress bubble
        // would hand the user an agent whose suspension linkage still points
        // through you.
        if (await AgentRunRegistry.shared.isAgentRunning(agentUUID: target.uuid)) {
            return "Error: '\(targetChat.title)' is currently mid-run. Wait for it to finish (or cancel it) before releasing."
        }
        guard (target.suspendData == nil) else {
            return "Error: '\(targetChat.title)' has a pending request awaiting a decision. Resolve it before releasing."
        }

        // Snapshot the freeze values NOW so the user approves exactly what
        // they will receive.
        let frozenMode = target.effectiveMode
        let frozenDirectories = target.effectiveDirectories
        let reason = (args["reason"] as? String) ?? ""

        let request = UserInputRequest(
            agentUUID: parent.uuid,
            userUUID: parent.userUUID,
            type: .confirmation,
            prompt: """
            Dawson requests to hand his worker '\(targetChat.title)' over to you \
            as a chat you own and prompt directly.\((reason.isEmpty) ? "" : "\n\nReason: \(reason)")

            It will be frozen at its current effective capabilities:
            Mode: \(frozenMode)
            Workspace: \(frozenDirectories.isEmpty ? "(none)" : frozenDirectories.joined(separator: ", "))

            After the handoff its mode no longer follows Dawson's — changing it \
            is up to you.
            """,
            toolCallName: ReleaseWorker.name
        )
        self.pending = PendingChildSuspension(
            kind: .workerRelease,
            childChatUUID: targetChat.uuid,
            childAgentUUID: target.uuid,
            taskTitle: targetChat.title
        )
        self.stagedBubble = request
        return "(Awaiting the user's approval to release the worker.)"
    }

    private func release(chatUUID: String, agentUUID: String, parent: Agent) -> String {
        guard let targetChat = DAWSON.shared.getChat(chatUUID),
              let target = AgentHandler.shared.getAgent(agentUUID) else {
            return "Error: That worker no longer exists."
        }
        // Conditions may have shifted while the approval sat with the user.
        guard (target.parentAgentUUID == parent.uuid) else {
            return "Error: '\(targetChat.title)' is no longer your worker; nothing was changed."
        }

        // FREEZE, then cut the tether — strictly in that order, because the
        // effective values are computed THROUGH the tether. Freezing to the
        // effective (not stored) values means release can only preserve or
        // shrink capability, matching attenuation.
        target.mode = target.effectiveMode
        target.directories = target.effectiveDirectories
        target.parentAgentUUID = nil
        target.updatedTimestamp = Date.now.epochMillis
        target.saveMetadata()
        DAWSON.shared.broadcastAgentUpsert(target)

        // Drop the worker glyph so the chat reads as the user's own.
        if (targetChat.title.hasPrefix("⚔ ")) {
            targetChat.title = String(targetChat.title.dropFirst(2))
            targetChat.saveMetadata()
        }

        return """
        Released '\(targetChat.title)' (chat UUID: \(chatUUID)) to the user at \
        \(target.mode) with workspace \(target.directories.isEmpty ? "(none)" : target.directories.joined(separator: ", ")). \
        It is now their chat; you can still reach it via \(TalkToAgent.name) under user-owned rules.
        """
    }
}

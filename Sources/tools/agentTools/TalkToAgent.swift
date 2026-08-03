//
//  TalkToAgent.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/28/26.
//

import Foundation

class TalkToAgent: ChatAware, DelegationBubbleAware {
    static let name = "talk_to_agent"

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
        Sends a message to an existing Squirebot chat and waits for its reply. \
        Works on your own workers (from \(DelegateTask.name) and on the user's own \
        Squirebot chats — in the latter, you speak with the user's authority in \
        that chat, and messaging one that currently outranks your mode first \
        requires the user's approval (raised automatically). The Squirebot \
        retains its full history; use this for revisions, follow-up questions, \
        answering a worker's earlier question, or relaying instructions the \
        user gave you for a specific chat. Use \(ListAgents.name) to see chats, \
        ownership, and modes.
        """

    private let parameterSchema: [String: Any] = [
        "type": "object",
        "required": ["chat_uuid", "message"],
        "properties": [
            "chat_uuid": [
                "type": "string",
                "description": "UUID of the Squirebot chat (from \(DelegateTask.name)'s report or \(ListAgents.name)"
            ],
            "message": [
                "type": "string",
                "description": "The message, instructions, or answer to send"
            ]
        ]
    ]

    func openAISchema() -> [String: Any] {
        return [
            "type": "function",
            "name": TalkToAgent.name,
            "description": toolDescription,
            "parameters": parameterSchema
        ]
    }

    func anthropicSchema() -> [String: Any] {
        return [
            "name": TalkToAgent.name,
            "description": toolDescription,
            "input_schema": parameterSchema
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": TalkToAgent.name,
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

        // --- Resume leg ---
        if let pending = self.pending {
            guard let response = self.stagedResponse else {
                return "Error: Resume reached without a user decision."
            }
            self.stagedResponse = nil
            self.pending = nil

            switch pending.kind {
            case .childRequest:
                // Decision relays down; the child executes under its own mode.
                let step = await DelegationRunner.resumeChild(pending: pending, response: response, parentAgent: parent)
                return handle(step, taskTitle: pending.taskTitle)

            case .modeDiscrepancy(let heldMessage):
                // Pre-flight approval to address a higher-mode user chat.
                guard (response.accepted == true) else {
                    return "The user declined your request to message '\(pending.taskTitle)' (it currently outranks your mode). The message was not sent."
                }
                guard let targetChat = DAWSON.shared.getChat(pending.childChatUUID) else {
                    return "Error: That chat no longer exists."
                }
                let step = await DelegationRunner.begin(
                    chat: targetChat,
                    childAgentUUID: pending.childAgentUUID,
                    parentAgent: parent,
                    taskTitle: targetChat.title,
                    prompt: heldMessage
                )
                return handle(step, taskTitle: targetChat.title)
                
            default:
                return "Error: Unexpected pending state for \(TalkToAgent.name)."
            }
        }

        // --- Fresh leg ---
        guard let chatUUID = args["chat_uuid"] as? String, !chatUUID.isEmpty else {
            return "Error: Missing required parameter 'chat_uuid'."
        }
        guard let rawMessage = args["message"] as? String, !rawMessage.isEmpty else {
            return "Error: Missing required parameter 'message'."
        }

        guard let targetChat = DAWSON.shared.getChat(chatUUID) else {
            return "Error: No chat found with UUID '\(chatUUID)'. Use \(ListAgents.name) to see existing agents and their chats."
        }
        guard (targetChat.userUUID == parentChat.userUUID) else {
            return "Error: That chat belongs to a different user."
        }
        guard (targetChat.uuid != parentChat.uuid) else {
            return "Error: You cannot delegate to yourself."
        }
        guard let target = AgentHandler.shared.getAgent(targetChat.agentUUID),
              (target.type == .squireBot) else {
            return "Error: \(TalkToAgent.name) can only address Squirebots."
        }

        // Visible attribution in the transcript (structured attribution via originActor is added by DelegationRunner.begin).
        let message = "[Message from Dawson]\n\n" + rawMessage

        // --- Ownership regimes ---
        if (target.parentAgentUUID == parent.uuid) {
            // Own worker. The live tether governs its power; just sanity-check that it still has ground to stand on.
            if (target.effectiveDirectories.isEmpty && !target.directories.isEmpty) {
                return "Error: This worker's workspace (\(target.directories.joined(separator: ", "))) is no longer within yours; ask the user to adjust workspaces before continuing with it."
            }
        } else if let otherParent = target.parentAgentUUID {
            return "Error: That Squirebot is operated by another agent (\(otherParent)) and cannot be addressed."
        } else {
            // User-owned chat. Outranking targets need the user's blessing.
            if (target.effectiveMode.rank > parent.effectiveMode.rank) {
                let request = UserInputRequest(
                    agentUUID: parent.uuid,
                    userUUID: parent.userUUID,
                    type: .permission,
                    prompt: """
                    Dawson requests to send a message to your chat '\(targetChat.title)', \
                    which operates at \(target.effectiveMode) — above his current \
                    \(parent.effectiveMode). If approved, his message enters that chat \
                    with your authority and the Squirebot acts on it under its own mode.

                    Message to be sent:
                    \(rawMessage)
                    """,
                    toolCallName: TalkToAgent.name,
                    metadata: [
                        "discrepancyTargetChatUUID": targetChat.uuid,
                        "discrepancyTargetAgentUUID": target.uuid
                    ]
                )
                self.pending = PendingChildSuspension(
                    kind: .modeDiscrepancy(pendingMessage: message),
                    childChatUUID: targetChat.uuid,
                    childAgentUUID: target.uuid,
                    taskTitle: targetChat.title
                )
                self.stagedBubble = request
                return "(Awaiting the user's approval to message a higher-mode chat.)"
            }
        }

        let step = await DelegationRunner.begin(
            chat: targetChat,
            childAgentUUID: target.uuid,
            parentAgent: parent,
            taskTitle: targetChat.title,
            prompt: message
        )
        return handle(step, taskTitle: targetChat.title)
    }

    private func handle(_ step: DelegationStep, taskTitle: String) -> String {
        switch step {
        case .completed(let outcome):
            return DelegationRunner.formatOutcome(outcome, taskTitle: taskTitle)
            
        case .needsUser(let request, let pendingState):
            self.pending = pendingState
            self.stagedBubble = request
            return "(Awaiting the user's decision on the worker's request.)"
        }
    }
}

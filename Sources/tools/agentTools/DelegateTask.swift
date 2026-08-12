//
//  DelegateTask.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/29/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

class DelegateTask: ChatAware, DelegationBubbleAware {
    static let name = "delegate_task"

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
        Delegates a task to a new worker Squirebot you own and waits for its \
        completed report. The worker runs at AT MOST your current permission \
        mode and within your current workspace — always, even if your mode \
        later changes. If the worker needs a permission the user must grant, \
        the request surfaces to the user through you automatically; if it asks \
        an informational question, the question appears in the report for you \
        to answer (via \(TalkToAgent.name) or to relay to the user first. Write the \
        brief as if for a competent worker with NO shared context: goal, \
        background, constraints, exact deliverable, and where in the workspace \
        to write outputs. Do NOT delegate anything you could finish yourself in \
        one or two tool calls. Follow up later with \(TalkToAgent.name) and the \
        returned chat UUID.
        """

    private let parameterSchema: [String: Any] = [
        "type": "object",
        "required": ["title", "task"],
        "properties": [
            "title": [
                "type": "string",
                "description": "Short task title (2-6 words) — becomes the chat title the user sees"
            ],
            "task": [
                "type": "string",
                "description": "Complete, self-contained brief: goal, background, constraints, exact deliverable, and output location. The worker has no context other than this."
            ],
            "mode": [
                "type": "string",
                "enum": ModeType.allCases.map { $0.rawValue },
                "description": "Permission mode for the worker. Clamped to your own mode; defaults to your mode. Grant the least the task needs."
            ],
            "workspace_directories": [
                "type": "array",
                "items": ["type": "string"],
                "description": "Workspace for the worker; must be within your own workspace. Defaults to your full workspace. Grant the least the task needs."
            ]
        ]
    ]

    func openAISchema() -> [String: Any] {
        return [
            "type": "function",
            "name": DelegateTask.name,
            "description": toolDescription,
            "parameters": parameterSchema
        ]
    }

    func anthropicSchema() -> [String: Any] {
        return [
            "name": DelegateTask.name,
            "description": toolDescription,
            "input_schema": parameterSchema
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": DelegateTask.name,
                "description": toolDescription,
                "parameters": parameterSchema
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let parentChat = chat,
              let parent = AgentHandler.shared.getAgent(parentChat.agentUUID) else {
            return "Error: Delegation is unavailable — no originating chat context."
        }
        
        guard (parentChat.isPrimaryChat) else {
            return "Error: Delegation is unavailable — only Dawson is allowed to delegate task."
        }

        // --- Resume leg: a bubbled request was decided by the user ---
        if let pending = self.pending {
            guard let response = self.stagedResponse else {
                return "Error: Delegation resume reached without a user decision."
            }
            self.stagedResponse = nil
            self.pending = nil

            let step = await DelegationRunner.resumeChild(pending: pending, response: response, parentAgent: parent)
            return handle(step, taskTitle: pending.taskTitle)
        }

        // --- Fresh leg ---
        guard let title = args["title"] as? String, !title.isEmpty else {
            return "Error: Missing required parameter 'title'."
        }
        guard let task = args["task"] as? String, !task.isEmpty else {
            return "Error: Missing required parameter 'task'."
        }

        // ATTENUATION at birth (the live tether keeps it true afterwards).
        let requestedMode = (args["mode"] as? String).flatMap(ModeType.fromName) ?? parent.effectiveMode
        let childMode = ModeType.lower(of: requestedMode, parent.effectiveMode)

        let requestedDirs = (args["workspace_directories"] as? [String]) ?? parent.effectiveDirectories
        if let offender = DelegationRunner.validateWorkspaceSubset(requested: requestedDirs, parent: parent.effectiveDirectories) {
            return """
            Error: '\(offender)' is outside your own workspace; a worker cannot be \
            granted directories you do not hold. Your workspace: \
            \(parent.effectiveDirectories.joined(separator: ", ")). If access is \
            genuinely needed, ask the user to widen your workspace first.
            """
        }

        let chatUUID = UUID().uuidString
        let agentUUID = UUID().uuidString
        await DAWSON.shared.createSquireChat(chatUUID: chatUUID, userUUID: parentChat.userUUID, agentUUID: agentUUID)

        guard let childChat = DAWSON.shared.getChat(chatUUID),
              let childAgent = AgentHandler.shared.getAgent(agentUUID) else {
            return "Error: Failed to create the worker's chat."
        }

        childChat.title = "⚔ \(title)"
        childChat.saveMetadata()

        childAgent.mode = childMode
        childAgent.directories = requestedDirs
        childAgent.parentAgentUUID = parent.uuid    // Dawson-owned: live tether
        childAgent.saveMetadata()
        DAWSON.shared.broadcastAgentUpsert(childAgent)

        let brief = """
        You are a Squirebot executing a task delegated by Dawson, the user's \
        primary assistant. Work autonomously within your permissions. If an \
        action requires approval, request it normally — it is routed to the \
        user through Dawson. Purely informational questions may not receive an \
        answer; prefer proceeding with reasonable judgment.

        == DELEGATED TASK: \(title) ==

        \(task)

        == REQUIRED FINAL REPORT ==
        End with a clear report: what was accomplished, exact paths of any \
        outputs, what failed or was blocked (and why), and anything Dawson \
        should verify.
        """

        let step = await DelegationRunner.begin(
            chat: childChat,
            childAgentUUID: agentUUID,
            parentAgent: parent,
            taskTitle: title,
            prompt: brief
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
            return "(Awaiting the user's decision on the worker's request.)"
        }
    }
}

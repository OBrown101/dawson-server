//
//  DelegationTask.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/28/26.
//

import Foundation

final class DelegationRunner {
    // BUBBLE-UP: child's permission/confirmation request becomes Dawson's
    // own suspension, surfaces to user in Dawson's chat, and decision
    // flows back down; the CHILD executes approved action under its own
    // mode. Query-type (.input) child requests are auto-answered with
    // guidance and surfaced in the report for Dawson to handle agentically.
    
    // BUSY DETECTION: a run that produced no new messages (target agent
    // already running, or provider failure) is reported as such — never stale message.
    
    // ATTRIBUTION: Dawson-injected prompts carry originActor metadata plus a
    // visible [Message from Dawson] prefix.
    

    private init() {}

    static let maxAutoInputs = 5    // Cap on auto-answered .input requests per delegation turn

    static func validateWorkspaceSubset(requested: [String], parent: [String]) -> String? {
        let parentCanonical = parent.map(FileUtilities.canonicalFilePath)
        for path in requested {
            let child = FileUtilities.canonicalFilePath(path)
            let contained = parentCanonical.contains { root in
                let r = root.hasSuffix("/") ? root : root + "/"
                return (child == root) || (child + "/").hasPrefix(r)
            }
            if (!contained) { return path }
        }
        return nil
    }

    static func begin(
        chat: Chat,
        childAgentUUID: String,
        parentAgent: Agent,
        taskTitle: String,
        prompt: String
    ) async -> DelegationStep {
        // Sends prompt into child chat, drives until completion/bubble-worthy suspension
        
        let baseline = chat.messages.count
        await chat.getResponse(
            runUUID: UUID().uuidString,
            prompt: prompt,
            originActor: parentAgent.type.name,
            onEvent: { _, _ in }
        )
        DAWSON.shared.broadcastChatMessages(chat)   // TODO: Need switch out for live stream (if possible)
        return await drive(
            chat: chat,
            childAgentUUID: childAgentUUID,
            parentAgent: parentAgent,
            taskTitle: taskTitle,
            baselineMessageCount: baseline,
            autoResolvedInputs: []
        )
    }

    static func resumeChild(
        pending: PendingChildSuspension,
        response: UserInputResponse,
        parentAgent: Agent
    ) async -> DelegationStep {
        // Relays user decision to suspended child (child executes approved action in own mode)
        
        guard let chat = DAWSON.shared.getChat(pending.childChatUUID) else {
            return .completed(
                DelegationOutcome(
                    report: "Error: the worker's chat (\(pending.childChatUUID)) no longer exists; the pending request could not be resolved.",
                    workerQuestions: pending.autoResolvedInputs,
                    chatUUID: pending.childChatUUID,
                    agentUUID: pending.childAgentUUID,
                    producedReply: false
                )
            )
        }

        let mapped = UserInputResponse(
            agentUUID: pending.childAgentUUID,
            userUUID: chat.userUUID,
            accepted: response.accepted,
            responseText: response.responseText
        )
        await chat.getResumedResponse(response: mapped, onEvent: { _, _ in })
        DAWSON.shared.broadcastChatMessages(chat)   // TODO: Need switch out for live stream (if possible)

        return await drive(
            chat: chat,
            childAgentUUID: pending.childAgentUUID,
            parentAgent: parentAgent,
            taskTitle: pending.taskTitle,
            baselineMessageCount: nil,
            autoResolvedInputs: pending.autoResolvedInputs
        )
    }

    private static func drive(
        chat: Chat,
        childAgentUUID: String,
        parentAgent: Agent,
        taskTitle: String,
        baselineMessageCount: Int?,
        autoResolvedInputs: [String]
    ) async -> DelegationStep {
        // Drives child until finishes/user-input
        // .input requests auto-answered (capped) and surfaced
        // .permission/.confirmation requests bubble
        
        var workerQuestions = autoResolvedInputs
        var autoInputCount = 0

        while let child = AgentHandler.shared.getAgent(childAgentUUID),
              let suspend = child.suspendData {
            let request = suspend.userInputRequest

            switch request.type {
            case .input:
                autoInputCount += 1
                workerQuestions.append(request.prompt)
                if (autoInputCount > maxAutoInputs) {
                    await child.cancelCurrentRun()
                    break
                }
                let auto = UserInputResponse(
                    agentUUID: childAgentUUID,
                    userUUID: chat.userUUID,
                    accepted: false,
                    responseText: """
                    AUTO-RESPONSE: No user is present in this delegated session. \
                    If you can proceed with reasonable judgment, do so; otherwise \
                    state precisely what you need in your final report and stop.
                    """
                )
                await chat.getResumedResponse(response: auto, onEvent: { _, _ in })
                DAWSON.shared.broadcastChatMessages(chat)   // TODO: Need switch out for live stream (if possible)

            case .permission, .confirmation:
                let bubbled = UserInputRequest(
                    agentUUID: parentAgent.uuid,
                    userUUID: parentAgent.userUUID,
                    type: request.type,
                    prompt: """
                    Worker request from '\(chat.title)' (operating at \(child.effectiveMode)):

                    \(request.prompt)

                    If approved, the worker performs this action itself, under its \
                    own permissions, in its own chat.
                    """,
                    toolCallName: request.toolCallName,
                    metadata: [
                        "bubbledFromAgentUUID": childAgentUUID,
                        "bubbledFromChatUUID": chat.uuid
                    ]
                )
                return .needsUser(
                    request: bubbled,
                    pending: PendingChildSuspension(
                        kind: .childRequest,
                        childChatUUID: chat.uuid,
                        childAgentUUID: childAgentUUID,
                        taskTitle: taskTitle,
                        autoResolvedInputs: workerQuestions
                    )
                )
            }
        }

        // Busy / no-reply detection: a fresh run that added NO messages means
        // the target agent was already running or the run failed. Never
        // scavenge a stale assistant message as if it were the reply.
        if let baseline = baselineMessageCount,
           (chat.messages.count <= baseline) {
            return .completed(DelegationOutcome(
                report: "No reply was produced — the agent was busy with another run or the run failed. Try again shortly.",
                workerQuestions: workerQuestions,
                chatUUID: chat.uuid,
                agentUUID: childAgentUUID,
                producedReply: false
            ))
        }

        let finalText = chat.messages
            .last(where: { ($0.sourceType == .response) && ($0.dataType == .text) })
            .flatMap { $0.payload.value as? String }
            ?? "(the agent produced no final response)"

        return .completed(
            DelegationOutcome(
                report: finalText,
                workerQuestions: workerQuestions,
                chatUUID: chat.uuid,
                agentUUID: childAgentUUID,
                producedReply: true
            )
        )
    }
}

extension DelegationRunner {
    static func formatOutcome(_ outcome: DelegationOutcome, taskTitle: String) -> String {
        var result = """
        == Report: \(taskTitle) ==
        (Chat UUID: \(outcome.chatUUID) — full transcript visible to client (e.g. Beakshield); \
        use \(TalkToAgent.name) with this chat UUID to follow up.)

        \(outcome.report)
        """

        if (!outcome.workerQuestions.isEmpty) {
            let questions = outcome.workerQuestions.map { "- \($0)" }.joined(separator: "\n")
            result += """


            [The worker asked \(outcome.workerQuestions.count) question(s) that were \
            auto-answered with 'proceed with your judgment'. If any need a real answer, \
            either answer from your own knowledge via \(TalkToAgent.name), or ask the user \
            first and relay the answer:
            \(questions)]
            """
        }

        return result
    }
}

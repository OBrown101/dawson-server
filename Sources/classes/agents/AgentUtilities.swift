//
//  AgentUtilities.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/13/26.
//

import Foundation

class AgentUtilities {
    static let convSummaryPrompt =
        """
        You are generating a chat subtitle.

        Task:
        Identify ONLY the most recent topic being discussed in the last few messages.

        Rules:
        - 2-6 words maximum.
        - No punctuation.
        - No complete sentences.
        - No explanations.
        - No prefixes like "Discussion about" or "Talking about".
        - Focus on the latest active topic, not the overall conversation.
        - If the topic changed recently, use the newest topic.
        - Return only the subtitle text.

        Examples:
        Kotlin WebSocket debugging
        Mempalace diary integration
        Agent suspension handling
        Swift concurrency issue
        Compose Multiplatform icons
        """
    
    static let memorySessionPrompt =
        """
        You are closing this session.

        If anything meaningful happened, call mempalace_diary_write to record what happened, what you learned, what matters.

        Also write durable memory if the session included:
        - user preferences
        - project decisions
        - changed facts
        - unresolved next steps
        - important debugging discoveries

        Do not respond to the user.
        Only call Mempalace tools if needed.
        """
    
    static func userInputText(request: UserInputRequest, response: UserInputResponse) -> String {
        switch (request.type) {
        case .permission:
            return """
            PERMISSION_RESULT
            
            Tool:
            \(request.toolCallName ?? "NONE")

            Decision:
            \((response.accepted ?? false) ? "APPROVED" : "DENIED")
            """
            
        case .confirmation:
            return """
            CONFIRMATION_RESULT
            
            Prompt:
            \(request.prompt)

            Decision:
            \((response.accepted ?? false) ? "CONFIRMED" : "REJECTED")
            """

        case .input:
            return """
            REQUEST_USER_INPUT_RESULT
            
            Prompt:
            \(request.prompt)
            
            User Response:
            \(response.responseText ?? "")
            """
        }
    }
    
    static func getWorkspacesPrompt(mode: ModeType, _ directories: [String]) -> String? {
        if (mode == .egg) {
            return nil
        }
        let directoryList = directories
            .map { "- \($0)" }
            .joined(separator: "\n")

        return """
            ## WORKSPACE ACCESS ##

            The directories below are the only user-selected workspaces available for this chat-session:

            \(directoryList)

            Rules:
            - Do not search outside these directories.
            - Do not read, write, patch, list, or reference files outside these directories.
            - If the user asks about a file, project, folder, workspace, repo, or similar, you MUST first utilize the neccessary tool to inquire inside these directories before answering.
            - If the user provides only a filename, search these directories for it.
            - Do not say you cannot access workspace files unless a workspace tool call actually fails.
            - If something cannot be found inside these directories after searching, say that it is not available with the current session settings.
            - Treat this list as current for this run; it may change between runs.
            """
    }
    
    static func getRunCancelledMessage(runUUID: String, streamState: StreamTempState) async -> Message? {
        let state = await streamState.snapshot()
        let trimmedContent = state.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedThinking = state.thinking.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard (!trimmedContent.isEmpty || !trimmedThinking.isEmpty) else { return nil }
        
        let text = (trimmedContent.isEmpty) ? "[Run interrupted while thinking.]" : "\(trimmedContent)\n\n[Run interrupted.]"
        return Message(runUUID: runUUID, role: MsgSource.assistant.name, text: text)
    }
}

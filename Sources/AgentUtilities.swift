//
//  AgentUtilities.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/13/26.
//

import Foundation

class AgentUtilities {
    static var convSummaryPrompt: String {
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
    }
    
    static var memorySessionPrompt: String {
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
    }
    
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
}

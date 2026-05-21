import Foundation

enum AgentConfigAction: String, Codable {
    case login
    case setMode
}

struct AgentConfigPayload: Codable {
    let action: AgentConfigAction
    let userUUID: String
    let mode: Mode? // optional for setMode
    let profile: UserProfile? // optional for login
}


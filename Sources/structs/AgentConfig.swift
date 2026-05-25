import Foundation

enum AgentConfigAction: String, Codable {
    case login
    case setMode
}

struct AgentConfigPayload: Codable {
    let action: AgentConfigAction
    let userUUID: String
    let mode: ModeType?
    let user: User?
}


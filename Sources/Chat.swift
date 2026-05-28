//
//  Chat.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/27/26.
//

import Foundation

class Chat: Codable {
    let uuid: String
    let userUUID: String
    let agentUUID: String
    
    var messages: [MessageData] = []
    
    init(uuid: String, userUUID: String, agentUUID: String = Agent.primaryAgentUUID) {
        self.uuid = uuid
        self.userUUID = userUUID
        self.agentUUID = agentUUID
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        uuid = try container.decode(String.self, forKey: .uuid)
        userUUID = try container.decode(String.self, forKey: .userUUID)
        agentUUID = try container.decode(String.self, forKey: .agentUUID)
    }
    
    func getResponse(prompt: String, onEvent: ((_ event: AgentEvent, _ runUUID: String) -> Void)? = nil) async {
        let newMessages = await AgentHandler.shared.runAgent(userUUID: userUUID, agentUUID: agentUUID, prompt: prompt, onEvent: onEvent)
        addNewMessageDatas(newMessages.compactMap({ MessageData.fromMessage($0, chatUUID: uuid, userUUID: userUUID, agentUUID: agentUUID) }))
    }
    
    func getResumedResponse(response: UserInputResponse, onEvent: ((_ event: AgentEvent, _ runUUID: String) -> Void)? = nil) async {
        let newMessages = await AgentHandler.shared.resumeAgent(response: response, onEvent: onEvent)
        addNewMessageDatas(newMessages.compactMap({ MessageData.fromMessage($0, chatUUID: uuid, userUUID: userUUID, agentUUID: agentUUID) }))
    }
}

extension Chat {
    private func addNewMessageDatas(_ messageDatas: [MessageData]) {
        messages.append(contentsOf: messageDatas)
        var timestamps = Set<Int64>()
        messages.removeAll { !timestamps.insert($0.timestamp).inserted }
    }
}

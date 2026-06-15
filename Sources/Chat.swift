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
    var title: String       // Set by user as overall chat topic
    var subtitle: String    // Set by agent as current discussion topic
    var updatedTimestamp: Int64
    
    static let chatsDirectory = DAWSON.workspace.appendingPathComponent("chats")
    
    var messages: [MessageData] = []
    
    init(uuid: String, userUUID: String, agentUUID: String, title: String = "", subtitle: String = "") {
        self.uuid = uuid
        self.userUUID = userUUID
        self.agentUUID = agentUUID
        self.title = title
        self.subtitle = subtitle
        self.updatedTimestamp = Int64(Date.now.timeIntervalSince1970)
    }
    
    enum CodingKeys: String, CodingKey {
        case uuid
        case userUUID
        case agentUUID
        case title
        case subtitle
        case updatedTimestamp
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        uuid = try container.decode(String.self, forKey: .uuid)
        userUUID = try container.decode(String.self, forKey: .userUUID)
        agentUUID = try container.decode(String.self, forKey: .agentUUID)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        updatedTimestamp = try container.decode(Int64.self, forKey: .updatedTimestamp)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(uuid, forKey: .uuid)
        try container.encode(userUUID, forKey: .userUUID)
        try container.encode(agentUUID, forKey: .agentUUID)
        try container.encode(title, forKey: .title)
        try container.encode(subtitle, forKey: .subtitle)
        try container.encode(updatedTimestamp, forKey: .updatedTimestamp)
    }
    
    func getResponse(runUUID: String, prompt: String, onEvent: ((_ event: AgentEvent, _ runUUID: String) -> Void)? = nil) async {
        let newMessages = await AgentHandler.shared.runAgent(runUUID: runUUID, userUUID: userUUID, agentUUID: agentUUID, prompt: prompt, onEvent: onEvent)
        let messageDatas = newMessages.compactMap({ MessageData.fromMessage($0, chatUUID: uuid, userUUID: userUUID, agentUUID: agentUUID) })
        updateTitles()
        addNewMessageDatas(messageDatas)
    }
    
    func getResumedResponse(response: UserInputResponse, onEvent: ((_ event: AgentEvent, _ runUUID: String) -> Void)? = nil) async {
        let newMessages = await AgentHandler.shared.resumeAgent(response: response, onEvent: onEvent)
        let messageDatas = newMessages.compactMap({ MessageData.fromMessage($0, chatUUID: uuid, userUUID: userUUID, agentUUID: agentUUID) })
        addNewMessageDatas(messageDatas)
    }
    
    private func updateTitles() {
        let summary = AgentHandler.shared.getAgent(agentUUID)?.getSummary() ?? ""
        title = (title.isEmpty) ? summary : title
        subtitle = summary
        updatedTimestamp = Int64(Date.now.timeIntervalSince1970)
        saveMetadata()
    }
}

extension Chat {
    private func addNewMessageDatas(_ messageDatas: [MessageData]) {
        messages.append(contentsOf: messageDatas)
        var timestamps = Set<Int64>()
        messages.removeAll { !timestamps.insert($0.timestamp).inserted }
        messages.forEach {
            try? appendMessageData($0, chatUUID: uuid)
        }
    }
}

extension Chat {
    static func loadAllChats() -> [Chat] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: chatsDirectory, includingPropertiesForKeys: nil) else { return [] }

        var chats: [Chat] = []
        for fileURL in files {
            guard (fileURL.pathExtension == "json"),
                  let data = try? Data(contentsOf: fileURL),
                  let chat = try? JSONDecoder().decode(Chat.self, from: data) else { continue }
            
            chat.messages = loadMessages(chatUUID: chat.uuid)
            chats.append(chat)
        }
        
        return chats.sorted { $0.messages.last?.timestamp ?? 0 > $1.messages.last?.timestamp ?? 0 }
    }
    
    static func loadChat(chatUUID: String) -> Chat? {
        let url = metadataURL(chatUUID: chatUUID)
        guard let data = try? Data(contentsOf: url),
              let chat = try? JSONDecoder().decode(Chat.self,from: data)  else { return nil }
        
        chat.messages = loadMessages(chatUUID: chatUUID)
        return chat
    }
    
    static func loadMessages(chatUUID: String) -> [MessageData] {
        let fileURL = messagesURL(chatUUID: chatUUID)
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return contents
            .split(separator: "\n")
            .compactMap { line in
                guard let data = line.data(using: .utf8) else { return nil }
                return try? decoder.decode(MessageData.self, from: data)
            }
    }
    
    func saveMetadata() {
        do {
            try FileManager.default.createDirectory(at: Chat.chatsDirectory, withIntermediateDirectories: true)
            
            let data = try JSONEncoder().encode(self)
            try data.write(to: Chat.metadataURL(chatUUID: uuid), options: .atomic)
            print("Successfully saved Chat \(uuid) metadata")
        } catch {
            print("Failed to save Chat \(uuid) metadata: ", error)
        }
    }
    
    func deleteAll() {
        let metaURL = Chat.metadataURL(chatUUID: uuid)
        let msgsURL = Chat.messagesURL(chatUUID: uuid)

        do {
            if FileManager.default.fileExists(atPath: metaURL.path) {
                try FileManager.default.removeItem(at: metaURL)
            }
            if FileManager.default.fileExists(atPath: msgsURL.path) {
                try FileManager.default.removeItem(at: msgsURL)
            }
            print("Successfully deleted Chat \(uuid) data")
        } catch {
            print("Failed to delete Chat \(uuid) data: ", error)
        }
    }
    
    private static func metadataURL(chatUUID: String) -> URL {
        return Chat.chatsDirectory.appendingPathComponent("metadata_\(chatUUID).json")
    }

    private static func messagesURL(chatUUID: String) -> URL {
        return Chat.chatsDirectory.appendingPathComponent("messages_\(chatUUID).jsonl")
    }
    
    private func appendMessageData(_ message: MessageData, chatUUID: String) throws {
        try appendMessageDatas([message], chatUUID: chatUUID)
    }
    
    private func appendMessageDatas(_ messageDatas: [MessageData], chatUUID: String) throws {
        let fileURL = Chat.messagesURL(chatUUID: chatUUID)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }

        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()

        for messageData in messageDatas {
            let jsonData = try encoder.encode(messageData)
            handle.write(jsonData)
            handle.write(Data("\n".utf8))
        }
    }
}

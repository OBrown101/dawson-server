//
//  MCPServer.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/10/26.
//

import Foundation
import MCP

final class MCPServer: @unchecked Sendable {
    let name: String
    let client: Client
    let transport: Transport

    init(
        name: String,
        client: Client,
        transport: any Transport
    ) {
        self.name = name
        self.client = client
        self.transport = transport
    }
}

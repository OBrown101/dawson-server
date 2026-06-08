//
//  main.swift
//  
//
//  Created by Ethan Brown on 4/13/26.
//

import Foundation
import Vapor

PythonEnv.setEnv()  // This must be setup before PythonKit is imported

let app = try await Application.make(.development)
defer {
    Task {
        try? await app.asyncShutdown()
    }
}

print("DAWSON started...")
let _ = ServerSettings.shared

app.http.server.configuration.hostname = "0.0.0.0"
app.http.server.configuration.port = 8080

app.webSocket("dawson") { req, ws in
    DAWSON.shared.server.handle(ws)
}

print("WebSocket running...")

try await app.execute()

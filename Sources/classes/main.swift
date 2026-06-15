//
//  main.swift
//  
//
//  Created by Ethan Brown on 4/13/26.
//

import Foundation
import Vapor
import NIOSSL

PythonEnv.setEnv()  // This must be setup before PythonKit is imported

try WebSocketSecurity.setup()

let app = try await Application.make(.development)
defer {
    Task {
        try? await app.asyncShutdown()
    }
}

print("DAWSON started...")
let _ = ServerSettings.shared

app.http.server.configuration.hostname = "0.0.0.0"
app.http.server.configuration.port = 8443
app.http.server.configuration.tlsConfiguration = .makeServerConfiguration(
    certificateChain: try NIOSSLCertificate
        .fromPEMFile(WebSocketSecurity.certPath.path)
        .map { .certificate($0) },
    privateKey: .privateKey(
        try NIOSSLPrivateKey(file: WebSocketSecurity.keyPath.path, format: .pem)
    )
)

app.webSocket("dawson") { req, ws in
    guard req.headers.bearerAuthorization?.token == (try? WebSocketSecurity.authToken()) else {
        try? await ws.close(code: .policyViolation)
        return
    }

    DAWSON.shared.server.handle(ws)
}

print("Secure WebSocket running...")

try await app.execute()

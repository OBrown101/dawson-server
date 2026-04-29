//
//  main.swift
//  
//
//  Created by Ethan Brown on 4/13/26.
//

import Foundation
import Vapor

let app = try await Application.make(.development)
defer { app.shutdown() }

let projectRoot = FileManager.default.currentDirectoryPath
let pythonLib = (projectRoot + "/python/python3/3.11/lib/libpython3.11.dylib")
setenv("PYTHON_LIBRARY", pythonLib, 1)

let dawson = DAWSON()

app.http.server.configuration.hostname = "0.0.0.0"
app.http.server.configuration.port = 8080

app.webSocket("dawson") { req, ws in
    dawson.server.handle(ws)
}

print("WebSocket running...")

try await app.execute()

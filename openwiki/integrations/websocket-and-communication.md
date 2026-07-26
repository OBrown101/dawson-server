---
type: Integration
title: WebSocket & Real-Time Communication
description: Secure TLS WebSocket server, packet protocol, authentication, and real-time event streaming between DAWSON and clients.
resource: /Sources/classes/websocket/
tags: [integration, communication, websocket, networking]
---

# WebSocket & Real-Time Communication

DAWSON uses secure WebSocket to provide real-time, bidirectional communication with clients. This document explains the protocol, authentication, packet format, and implementation details.

## Server Setup

### Initialization

**Location:** `/Sources/classes/main.swift`

```swift
import Vapor
import NIOSSL

// 1. Setup TLS certificates
PythonEnv.setEnv()
try WebSocketSecurity.setup()  // Generate or load certs

// 2. Create Vapor app
let app = try await Application.make(.development)

// 3. Configure TLS
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

// 4. Register WebSocket endpoint
app.webSocket("dawson", maxFrameSize: 64_000) { req, ws in
    // Authenticate
    guard req.headers.bearerAuthorization?.token == (try? WebSocketSecurity.authToken()) else {
        try? await ws.close(code: .policyViolation)
        return
    }
    
    // Handle connection
    DAWSON.shared.server.handle(ws)
}

// 5. Run server
try await app.execute()
```

### TLS Security

**Certificate Generation:** `/Sources/classes/websocket/WebSocketSecurity.swift`

```swift
// Self-signed certificate, valid for 10 years
openssl req -x509 -newkey rsa:4096 \
  -keyout privkey.pem -out fullchain.pem \
  -days 3650 -nodes \
  -subj "/CN=DAWSON Local"
```

**Auth Token:** 64-character hex string (256 bits)

```swift
// Generate at startup if not present
openssl rand -hex 32  // 64 hex chars = 256 bits
```

**Certificate Fingerprint:** SHA-256 hash

```swift
// Used by clients to verify certificate authenticity
openssl x509 -in fullchain.pem -noout -fingerprint -sha256
```

## Client Connection

### Connecting

```javascript
// Beakshield client
const token = localStorage.getItem('auth-token')
const ws = new WebSocket('wss://localhost:8443/dawson', {
    headers: {
        'Authorization': `Bearer ${token}`
    }
})

ws.addEventListener('open', () => console.log('Connected'))
ws.addEventListener('message', (event) => handlePacket(JSON.parse(event.data)))
ws.addEventListener('error', (error) => console.error('WebSocket error:', error))
ws.addEventListener('close', () => console.log('Disconnected'))
```

### Heartbeat

Keep connection alive:

```javascript
// Client: Send ping every 30 seconds
setInterval(() => {
    ws.send(JSON.stringify({
        type: 'ping',
        payload: 'ping'
    }))
}, 30000)

// Server: Respond with pong
ws.onmessage((packet) => {
    if (packet.type === 'ping') {
        ws.send(JSON.stringify({
            type: 'pong',
            payload: 'pong'
        }))
    }
})
```

## Packet Protocol

### Packet Structure

```swift
struct WSPacket: Codable {
    let type: PacketType
    let payload: AnyCodable        // Flexible JSON
    let isChunk: Bool = false      // Large payload chunking
    let transferUUID: String? = nil     // Chunk tracking ID
    let index: Int? = nil          // Chunk index
    let total: Int? = nil          // Total chunks
}

enum PacketType: String, Codable {
    case ping, pong
    case userData              // User message, approval response
    case chatData              // Chat metadata, list, create
    case configData            // Provider config, mode change
    case syncState             // User login, session sync
    case agentData             // Agent events (thinking, content, tool calls)
    case userInputRequest      // Request user input
    case error                 // Error message
}
```

### Packet Examples

**Ping (Client → Server):**
```json
{
  "type": "ping",
  "payload": "ping"
}
```

**User Message (Client → Server):**
```json
{
  "type": "userData",
  "payload": {
    "chatUUID": "chat-abc-123",
    "dataUUID": "run-456",
    "userUUID": "user-alice",
    "dataType": "textPrompt",
    "data": "Help me debug this Swift error"
  }
}
```

**Agent Content Event (Server → Client):**
```json
{
  "type": "agentData",
  "payload": {
    "dataType": "textResponse",
    "data": "I'll help you debug this error..."
  }
}
```

**Tool Call Event (Server → Client):**
```json
{
  "type": "agentData",
  "payload": {
    "dataType": "toolCall",
    "data": "read_file /path/to/file.swift"
  }
}
```

## Large Payload Chunking

For responses > 32 KB, sender chunks the payload:

**Server chunking logic:**
```swift
let maxChars = 32_000
if text.count > maxChars {
    let chunks = text.chunked(into: maxChars)
    let transferID = UUID().uuidString
    
    for (index, chunk) in chunks.enumerated() {
        let packet = WSPacket(
            type: originalType,
            payload: chunk,
            isChunk: true,
            transferUUID: transferID,
            index: index,
            total: chunks.count
        )
        try await ws.send(encodePacket(packet))
    }
} else {
    // Send as single packet
    try await ws.send(encodePacket(packet))
}
```

**Client reconstruction:**
```javascript
const chunkBuffers = {}

ws.onmessage((packet) => {
    if (packet.isChunk) {
        const { transferUUID, index, total } = packet
        
        if (!chunkBuffers[transferUUID]) {
            chunkBuffers[transferUUID] = new Array(total)
        }
        
        chunkBuffers[transferUUID][index] = packet.payload
        
        // Check if all chunks received
        if (chunkBuffers[transferUUID].every(c => c !== undefined)) {
            const fullPayload = chunkBuffers[transferUUID].join('')
            processPacket({ ...packet, payload: fullPayload, isChunk: false })
            delete chunkBuffers[transferUUID]
        }
    } else {
        processPacket(packet)
    }
})
```

## Packet Types & Handlers

### userData (Client → Server)

User sends message or responds to user input request:

```json
{
  "type": "userData",
  "payload": {
    "chatUUID": "chat-123",
    "dataUUID": "run-456",
    "userUUID": "user-alice",
    "dataType": "textPrompt",
    "payload": "Your message here"
  }
}
```

**Handler:** `WebSocketServer.handleUserData()`
- Dispatches agent execution with streaming
- Emits events back to client via `onEvent` callback

### chatData (Client → Server)

Create/load chat, update metadata:

```json
{
  "type": "chatData",
  "payload": {
    "chatUUID": "chat-123",
    "userUUID": "user-alice",
    "title": "Swift Debugging",
    "action": "load"  // or "create"
  }
}
```

**Handler:** `WebSocketServer.handleChatData()`
- Loads or creates chat
- Persists metadata
- Returns chat state to client

### configData (Client → Server)

Change provider, model, mode:

```json
{
  "type": "configData",
  "payload": {
    "userUUID": "user-alice",
    "provider": "anthropic",
    "model": "claude-3-5-sonnet-20241022",
    "mode": "warrior"
  }
}
```

**Handler:** `WebSocketServer.handleConfigData()`
- Validates configuration
- Updates provider/model/mode for user
- Persists changes

### agentData (Server → Client)

Real-time agent events:

```json
{
  "type": "agentData",
  "payload": {
    "dataType": "textThinking",
    "data": "Let me analyze this error..."
  }
}
```

**Data Types:**
- `textThinking` — Extended thinking from model
- `textResponse` — Model's response text
- `toolCall` — Tool invocation (name + args)
- `toolResult` — Tool execution result
- `agentState` — Agent state change (running, idle, error)

## Streaming Message Flow

```
Client sends: userData(textPrompt)
    ↓
WebSocketServer.handleUserData()
    ├─ Creates AgentEventStreamState
    ├─ Dispatches agent execution with onEvent callback
    │
    ├─ Agent emits: AgentEvent.thinking("...")
    │   └─ onEvent() sends agentData(textThinking)
    │
    ├─ Agent emits: AgentEvent.toolCall("read_file /path")
    │   └─ onEvent() sends agentData(toolCall)
    │
    ├─ Agent emits: AgentEvent.toolResult("File content...")
    │   └─ onEvent() sends agentData(toolResult)
    │
    ├─ Agent emits: AgentEvent.content("I found the bug...")
    │   └─ onEvent() sends agentData(textResponse)
    │
    └─ Agent emits: AgentEvent.agentState(.idle)
        └─ onEvent() sends agentData(agentState)
            ↓
        Client UI updates in real-time
```

## Error Handling

### Connection Errors

**Authentication Failure:**
```swift
// Server: Invalid or missing auth token
guard req.headers.bearerAuthorization?.token == (try? WebSocketSecurity.authToken()) else {
    try? await ws.close(code: .policyViolation)  // Close with policy violation
    return
}
```

**Malformed Packet:**
```swift
guard let data = json.data(using: .utf8),
      let packet: WSPacket = try? JSONDecoder().decode(WSPacket.self, from: data) else {
    // Log and ignore malformed packet; connection remains open
    return
}
```

### Network Errors

**Timeout:** Heartbeat (ping/pong) detects stale connections

**Disconnection:** Client reconnects; can resume chat by UUID

**Large Payload Timeout:** 32KB chunks sent immediately; reassembled on client side

## Performance

| Metric | Value |
|--------|-------|
| Max frame size | 64 KB |
| Max chunk size | 32 KB |
| Ping/pong frequency | 30 sec |
| Connection timeout | (Vapor default) |
| Max concurrent connections | (Limited by OS) |

## Security Considerations

1. **TLS 1.3** — Encrypted transport
2. **Bearer Token** — Simple but effective; rotate token on deployment
3. **Self-Signed Cert** — Client must trust fingerprint on first connection
4. **No replay protection** — Packets can be replayed (acceptable for this threat model)
5. **No rate limiting** — Future: implement per-connection rate limits

## Future Improvements

- **JWT auth** — Better token management with expiry
- **Message signing** — Detect tampering
- **Compression** — Gzip large payloads
- **Binary protocol** — More efficient than JSON
- **Reconnection handshake** — Resume partial agent runs
- **Client certificates** — Mutual TLS for Beakshield

## Next Steps

- **[Message Flow](/openwiki/workflows/message-flow.md)** — Complete end-to-end request tracing
- **[Architecture Overview](/openwiki/architecture/overview.md)** — WebSocket server in context

---
type: Workflow
title: Message Flow & WebSocket Communication
description: End-to-end flow of user messages, WebSocket packet handling, agent dispatch, and real-time event streaming back to clients.
resource: /Sources/classes/websocket/WebSocketServer.swift
tags: [workflow, communication, websocket, realtime]
---

# Message Flow & WebSocket Communication

This document traces how a user message flows from a client through DAWSON's WebSocket server, into agent execution, and back as streaming events.

## Architecture Overview

```
Client (Beakshield)
    │
    ├─ WebSocket: wss://localhost:8443/dawson
    │
    └─→ [TLS + Bearer Token Auth]
           │
           ▼
    WebSocketServer
    (Packet Routing)
           │
    ┌──────┴──────┬──────────────┬───────────────┐
    │             │              │               │
    ▼             ▼              ▼               ▼
 syncState    chatData       userData        configData
    │             │              │
    │             ▼              ▼
    │          Chat.load      Agent.run()
    │          Chat.create         │
    │                              ├─ Emit: thinking
    │                              ├─ Emit: toolCall
    │                              ├─ Emit: toolResult
    │                              ├─ Emit: content
    │                              └─ Emit: agentState
    │                                 │
    └─────────────────────────────────┘
                 │
                 ▼
         WebSocket Send Events
         (Real-time to client)
```

## Detailed Flow: User Sends Message

### Step 1: Client Establishes Connection

**Client initiates:**
```javascript
// Beakshield (Kotlin)
const ws = new WebSocket("wss://localhost:8443/dawson", 
  headers: { Authorization: "Bearer <token>" }
)
ws.onopen = () => console.log("Connected")
```

**Server authenticates:**
```swift
// main.swift: WebSocket endpoint handler
app.webSocket("dawson", maxFrameSize: 64_000) { req, ws in
    guard req.headers.bearerAuthorization?.token == (try? WebSocketSecurity.authToken()) else {
        try? await ws.close(code: .policyViolation)
        return
    }
    DAWSON.shared.server.handle(ws)  // Register connection
}
```

**Server accepts:**
- Generates unique UUID for this connection
- Stores in `WebSocketServer.connections` dictionary
- Sets up event handlers: `onText`, `onClose`

### Step 2: Client Sends Chat Message

**Client constructs packet:**
```json
{
  "type": "userData",
  "payload": {
    "chatUUID": "chat-abc-123",
    "dataUUID": "run-456",
    "userUUID": "user-alice",
    "dataType": "textPrompt",
    "data": "Help me debug this Swift error"
  },
  "isChunk": false
}
```

**Client sends over WebSocket:**
```
ws.send(JSON.stringify(packet))
```

### Step 3: Server Receives & Routes Packet

**Server entry point:**
```swift
// WebSocketServer.onReceive(json:ws:)
guard let data = json.data(using: .utf8),
      let packet: WSPacket = try? JSONDecoder().decode(WSPacket.self, from: data) else {
    return  // Malformed packet
}

switch packet.type {
case .userData:
    guard let payload: UserData = guardPayload(packet.payload) else { return }
    await handleUserData(payload, ws: ws)
    // ... other cases ...
}
```

**Packet structure:**
```swift
struct WSPacket: Codable {
    let type: PacketType       // userData, ping, configData, etc.
    let payload: AnyCodable    // Flexible JSON payload
    let isChunk: Bool          // Part of chunked transfer?
    let transferUUID: String?  // For large payloads (chunking)
    let index: Int?            // Chunk index
    let total: Int?            // Total chunks
}
```

### Step 4: Handle Chat Data Packet

**Server extracts user message:**
```swift
private func handleUserData(_ userData: UserData, ws: WebSocket) async {
    guard let textPrompt: String = guardPayload(userData.payload) else { return }
    
    // 1. Create streaming state tracker
    let streamState = AgentEventStreamState()
    
    // 2. Get or create chat
    // This resolves Chat from UUID (DAWSON.getChat)
    // or creates new Chat if it doesn't exist
    
    // 3. Dispatch agent execution with streaming callback
    await dawson.getChatResponse(
        chatUUID: userData.chatUUID,
        runUUID: userData.dataUUID,
        prompt: textPrompt,
        onEvent: { event, runUUID in
            // Handle each event emitted by agent
            await handleAgentEvent(event, ws: ws)
        }
    )
}
```

### Step 5: DAWSON Routes to Chat

**DAWSON orchestrator:**
```swift
// DAWSON.getChatResponse(chatUUID:runUUID:prompt:onEvent:)
func getChatResponse(
    chatUUID: String,
    runUUID: String,
    prompt: String,
    onEvent: @escaping (AgentEvent, String) async -> Void
) async {
    // Resolve or create chat
    guard let chat = activeChats[chatUUID] else {
        // Create new chat
        let chat = Chat(uuid: chatUUID, userUUID: userUUID, agentUUID: agentUUID)
        activeChats[chatUUID] = chat
    }
    
    // Dispatch to chat's agent
    await chat.getResponse(runUUID: runUUID, prompt: prompt, onEvent: onEvent)
}
```

### Step 6: Chat Dispatches to Agent

**Chat execution:**
```swift
// Chat.getResponse(runUUID:prompt:onEvent:)
public func getResponse(
    runUUID: String,
    prompt: String,
    onEvent: @escaping (AgentEvent, String) async -> Void
) async {
    // Create or resume agent
    if agent == nil {
        agent = Agent(
            uuid: agentUUID,
            userUUID: userUUID,
            type: .squirebot,
            mode: .warrior,
            model: userPreferredModel
        )
    }
    
    // Start agent execution
    try await agent?.run(
        runUUID: runUUID,
        prompt: prompt,
        onEvent: onEvent
    )
    
    // Persist chat after agent finishes
    await save()
}
```

### Step 7: Agent Executes & Streams Events

**Agent main loop emits events:**

```
┌─────────────────────────────────────┐
│  Agent.run() starts                 │
│  ├─ Prepare messages + tools        │
│  ├─ Call provider (Anthropic API)   │
│  └─ Stream response chunks          │
└────────────┬────────────────────────┘
             │
      ┌──────▼──────┐
      │ Emit events │
      └──────┬──────┘
             │
    ┌────────┴────────┬────────────┬────────────┬─────────┐
    │                 │            │            │         │
    ▼                 ▼            ▼            ▼         ▼
  Thinking      ToolCall      ToolResult    Content   AgentState
  "Checking     "read_file    "/path/to/    "I found  .running
   the error    /error.log"   error.log:    the bug   →
   file..."                   [16 lines]    in..."    .idle
```

**Event emission:**
```swift
// From Agent.run()
onEvent(.thinking("Let me analyze this error..."))

onEvent(.toolCall("read_file /path/to/main.swift"))
// ... tool executes ...
onEvent(.toolResult("File contains: \n [...]\n"))

onEvent(.content("I found the issue on line 42..."))

onEvent(.agentState(.idle))  // Run complete
```

### Step 8: WebSocket Server Sends Events Back to Client

**Event handler converts to packets:**
```swift
// WebSocketServer.handleAgentEvent()
case .thinking(let text):
    let packet = WSPacket(
        type: .agentData,
        payload: AgentData(
            dataType: .textThinking,
            data: text
        )
    )
    await send(packet, ws: ws)

case .content(let text):
    let packet = WSPacket(
        type: .agentData,
        payload: AgentData(
            dataType: .textResponse,
            data: text
        )
    )
    await send(packet, ws: ws)

// ... more cases ...
```

**Chunking large payloads:**
```swift
// If packet exceeds 32KB, split into chunks
if text.count > 32_000 {
    let chunks = text.chunked(into: 32_000)
    for (index, chunk) in chunks.enumerated() {
        let chunkPacket = WSPacket(
            type: originalType,
            payload: chunk,
            transferUUID: UUID().uuidString,
            index: index,
            total: chunks.count
        )
        try? await ws.send(encodePacket(chunkPacket))
    }
}
```

### Step 9: Client Receives & Reconstructs Events

**Client listener:**
```javascript
// Beakshield
ws.onmessage = (event) => {
  const packet = JSON.parse(event.data)
  
  if (packet.isChunk) {
    // Reassemble chunks
    chunkBuffer[packet.transferUUID] = chunkBuffer[packet.transferUUID] || []
    chunkBuffer[packet.transferUUID][packet.index] = packet.payload
    
    if (allChunksReceived(packet.transferUUID)) {
      const fullPayload = chunkBuffer[packet.transferUUID].join('')
      handleEvent(fullPayload)
    }
  } else {
    handleEvent(packet)
  }
}

handleEvent = (packet) => {
  switch (packet.type) {
    case 'agentData':
      if (packet.dataType === 'textThinking') {
        showThinkingBubble(packet.data)
      }
      if (packet.dataType === 'textResponse') {
        appendToMessage(packet.data)
      }
      break
  }
}
```

**UI updates in real-time:**
1. User sees thinking bubble appear with streamed text
2. Tool calls displayed as they execute
3. Final content appended to message
4. Agent state change shows "complete"

## Special Cases

### Large Prompt or History

If user's message + chat history exceeds context window:

```
1. Agent detects: messageSize > 80% of contextWindow
2. Compaction triggered: Old messages summarized
3. Summary replaces history
4. Agent continues with compact history + recent messages
```

### Tool Execution with User Input Request

If agent calls `RequestUserInput` tool:

```
Agent execution paused
    ↓
emit UserInputRequest event
    ↓
Client prompts user
    ↓
Client sends UserInputResponse
    ↓
WebSocketServer routes to agent
    ↓
Agent resumes with user's input in history
    ↓
Loop continues
```

### Permission Denied

Agent attempts to execute tool in a mode that forbids it:

```
Agent calls RunCommand("rm -rf /")
    ↓
Mode.guardRequests() throws PermissionDenied
    ↓
emit toolResult("Mode does not allow this command")
    ↓
Agent sees error, adjusts strategy or informs user
```

### Provider Rate Limit or Network Error

API call fails (network, rate limit, model error):

```
provider.call() throws error
    ↓
Agent catches, emits error event
    ↓
Chat receives error
    ↓
User sees error message
    ↓
Can retry, switch provider, or continue conversation
```

## Packet Types Reference

| Type | Source | Purpose |
|------|--------|---------|
| `ping` | Client | Heartbeat / connection check |
| `pong` | Server | Echo ping |
| `userData` | Client | User message, user input response |
| `chatData` | Client | Create/load chat, set metadata |
| `configData` | Client | Provider config, model selection, mode change |
| `syncState` | Client | Sync user/chat state (login, chat list) |
| `agentData` | Server | Agent events (thinking, content, tool calls, results) |
| `error` | Server | Error message |

## Performance Considerations

### Latency
- **WebSocket overhead:** ~5-10ms per message
- **Provider API call:** 1-5 seconds for Anthropic/OpenAI; ~100ms for Ollama
- **Chunking:** Adds negligible overhead; transparent to client

### Throughput
- **32KB packet limit per frame:** Large responses chunked automatically
- **Concurrent connections:** WebSocketServer handles N concurrent connections (Vapor async)
- **Message queue:** No backpressure mechanism currently; fast clients assumed

### Stream Ordering
- Events emitted in order: thinking → content → toolCall → toolResult → agentState
- Large payloads (chunked) reconstructed in order before client processes

## Error Handling & Recovery

### WebSocket Connection Lost
- Client: Detect `ws.onclose`, attempt reconnect
- Server: Remove from `connections` dict; no impact on active chat
- Resume: Client resends last message or reconnects to existing chat

### Malformed Packet
- Server: Decode fails → return (silent drop)
- Client: Invalid JSON → error logged, connection continues

### Agent Crash
- Rare, but if Agent.run() throws uncaught error
- Chat receives error event; user informed
- Chat remains in database; can retry

## Next Steps

- **[Agent Lifecycle](/openwiki/workflows/agent-lifecycle.md)** — Detailed agent.run() execution
- **[Security & Modes](/openwiki/security/modes-and-permissions.md)** — Permission evaluation
- **[Data & Storage](/openwiki/data-and-storage/persistence.md)** — Chat persistence details

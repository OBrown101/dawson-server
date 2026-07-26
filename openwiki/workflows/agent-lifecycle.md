---
type: Workflow
title: Agent Lifecycle & Execution
description: How DAWSON agents are created, execute, interact with LLMs and tools, and how iterations flow through the run loop.
resource: /Sources/classes/agents/Agent.swift
tags: [workflow, agent, execution, llm-integration]
---

# Agent Lifecycle & Execution

This document traces how an agent is created, the main execution loop, how tools are invoked, and how runs finalize.

## Agent Lifecycle Phases

```
┌──────────────────────────────────────────────────────────────┐
│  1. CREATION                                                 │
│  Agent(uuid, userUUID, mode, model, directories)            │
│  Binds provider, initializes runner, tool list               │
└──────────────────────────┬───────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────┐
│  2. INITIALIZATION                                            │
│  Agent.run(prompt) called with streaming callback            │
│  History prepared, permissions evaluated                     │
└──────────────────────────┬───────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────┐
│  3. EXECUTION LOOP (iterate until stop signal)               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ a. Prepare: Format messages, system prompt, tools    │   │
│  │ b. Call: Send to LLM provider                        │   │
│  │ c. Parse: Extract content, thinking, tool calls     │   │
│  │ d. Emit: Stream events to client                    │   │
│  │ e. Tool execution: Check perms, run, collect result │   │
│  │ f. Append: Add tool results to message history      │   │
│  │ g. Check: Iteration limit? Stop signal? Loop again  │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────────┬───────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────┐
│  4. FINALIZATION                                             │
│  Persist messages, save chat metadata, emit final events     │
│  Optional: Collect durable memory (MemPalace diary)          │
└──────────────────────────┬───────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────┐
│  5. READY FOR NEXT RUN                                       │
│  Chat contains persisted history; next prompt loads and runs │
└──────────────────────────────────────────────────────────────┘
```

## Detailed Execution Loop

### Phase 1: Creation

```swift
// Typically called from Chat when user sends first message
let agent = Agent(
    uuid: UUID().uuidString,
    userUUID: "user-123",
    providerType: .anthropic,
    type: .squirebot,
    mode: .warrior,
    model: LLMModel(id: "claude-3-5-sonnet", provider: .anthropic),
    thoughtWindow: 5,
    contextWindow: 200000,
    useThinking: true,
    directories: ["/Users/alice/Projects", "/tmp"]
)
```

**What happens:**
- Agent UUID, user UUID, mode, and model are bound
- `provider` is resolved via `Provider.provider(for:)` → appropriate `LLMProvider` instance
- `AgentRunner` actor created to manage execution state (prevent concurrent runs)
- `optionalTools` list initialized (file I/O, Python, commands, etc.)
- `requiredTools` always available (user input, env awareness, memory access, skill lookup)

### Phase 2: Initialization

```swift
// From Chat.getResponse(prompt, onEvent:)
await agent.run(runUUID: "run-456", prompt: "Help me debug this Swift error", onEvent: { event, _ in
    // Emit to WebSocket
    await webSocket.send(event)
})
```

**What happens:**
1. **Mark running:** `AgentRunner.start()` throws if already running (prevents concurrent invocations)
2. **Prepare history:** Load messages from `chat.messages`; limit to recent N messages if context full
3. **Format system prompt:** Include mode description, tool definitions, skill manifests
4. **Set up context:** User's message added to conversation history
5. **Initialize tracking:** Empty `toolResults` map, zero iteration counter

### Phase 3a: Prepare Messages (Loop Start)

```
Conversation history:
[
  { role: "user", content: "Debug this error..." },
  { role: "assistant", content: "I'll help you..." },
  { role: "user", content: "Here's the code..." }
]

System prompt (summarized):
"You are a task-focused agent. You have access to tools like ReadFile, RunCommand, etc. 
Mode: WARRIOR (full file/command access, iteration limit: 20).
Available skills: [migrate-wiki-to-okf, write-connector]"

Tools definitions (to provider):
[
  {
    name: "read_file",
    description: "Read a file from disk",
    inputSchema: { path: "/Users/...", maxLines: 100 }
  },
  ...15 more tools...
]
```

**What happens:**
- Messages formatted per provider spec (Anthropic uses content blocks, OpenAI uses role/content)
- Tool definitions serialized
- Thinking window configured (if useThinking=true)
- Context window checked; if messages exceed ~80% of limit, older messages compacted via summarization

### Phase 3b: Call LLM Provider

```swift
let response = try await provider.call(
    messages: formattedMessages,
    tools: toolDefinitions,
    model: agent.model.id,
    systemPrompt: systemPrompt,
    useThinking: true
)
```

Provider-specific behavior:

**Anthropic:**
- `ExtendedThinking` enabled if `useThinking=true`
- Thought blocks parsed separately from content
- Tool use blocks have structured tool_name, tool_use_id, input JSON

**OpenAI:**
- Tools defined in `tools` array with OpenAI JSON schema
- GPT-4o handles vision if agent has image attachments
- Parallel tool calling supported

**Ollama:**
- Tools defined but may not be used (local models often don't support)
- Streaming chunked response
- Lower latency, no API calls outside local network

### Phase 3c: Parse Response & Emit Events

```swift
// Provider returns: ProviderResponse
let response: ProviderResponse = {
    content: "I'll read the error file first...",
    thinking: "The user mentioned a Swift compilation error...",
    toolCalls: [
        ToolCall(id: "tool-1", name: "read_file", args: { path: "/path/to/error.swift" })
    ]
}

// Emit events
onEvent(.thinking(response.thinking))           // "I'll check the error file..."
onEvent(.content(response.content))             // "I'll read the error file first..."
onEvent(.toolCall("read_file /path/to/error.swift"))
```

**What happens:**
- Response object created from provider-specific JSON
- Thinking extracted (if present) and emitted
- Content text emitted (assistant's reasoning/plan)
- Tool calls parsed into structured list
- Each tool call generates `toolCall` event for real-time client updates

### Phase 3d: Execute Tools & Check Permissions

```swift
for toolCall in response.toolCalls {
    // 1. Find tool by name
    guard let tool = agent.tools.first(where: { $0.name == toolCall.name }) else {
        // Emit error, append to history
        continue
    }
    
    // 2. Evaluate permissions
    let permissionRequests = tool.permissionRequests(args: toolCall.args, agent: agent)
    // Example: RunCommand needs to validate command (mode-dependent)
    
    let evaluations = mode.evaluateRequests(permissionRequests, agent: agent)
    // Mode checks: is command whitelisted? is directory in scope?
    
    // 3. Gate on mode
    try mode.guardRequests(permissionRequests, agent: agent)
    // Throws if mode doesn't allow (e.g., RunCommand in Egg mode)
    
    // 4. Execute
    let result = try await tool.execute(args: toolCall.args)
    
    // 5. Emit result
    onEvent(.toolResult(result.description))
    
    // 6. Record for context
    toolResults[toolCall.id] = result
}
```

**Permission flow:**

| Mode | RunCommand | ReadFile | WriteFile | Python | Iteration Limit |
|------|-----------|----------|-----------|--------|-----------------|
| **Egg** | ❌ | ❌ | ❌ | ❌ | 5 |
| **Fledgling** | 🟡 Safe only | ✅ Whitelisted | ✅ Whitelisted | 🟡 Limited | 10 |
| **Warrior** | ✅ Approval-gated | ✅ In scope | ✅ In scope | ✅ Sandboxed | 20 |
| **Ultimate** | ✅ Unrestricted | ✅ Any | ✅ Any | ✅ Unrestricted | None |

### Phase 3e: Append Tool Results to History

```swift
// After tool executions complete:
messages.append(Message(
    role: "assistant",      // Tool results attributed to assistant
    text: nil,              // No text (tool use block)
    toolCalls: response.toolCalls,
    createdAt: Date.now
))

messages.append(Message(
    role: "user",           // Results presented as user role (per LLM convention)
    text: toolResults.map { "Tool \($0.id): \($0.result)" }.joined(separator: "\n"),
    toolCallId: toolCall.id
))
```

**What happens:**
- Tool call message appended (preserves intent)
- Tool result message appended (LLM can see outcomes)
- History grows; will be sent back to provider in next iteration

### Phase 3f: Check Stop Signals & Iteration Limit

```swift
// Stop conditions:
let shouldStop = response.stopReason == "end_turn"  // Model signaled it's done
    || iterationCount >= (mode.iterationLimit ?? Int.max)
    || response.toolCalls.isEmpty && shouldStop     // No more tool calls + model stopped
    || suspendData != nil                            // User interacted (suspension)

if shouldStop {
    // Break loop, go to finalization
} else {
    // Increment counter
    iterationCount += 1
    // Loop back to Phase 3a
}
```

**Typical loop:**
1. First iteration: User message → Model thinks + plans
2. Second iteration: Model calls read_file → Tool result appended → Loop
3. Third iteration: Model calls run_command → Result appended → Loop
4. Fourth iteration: Model stops (no more tool calls) → Break

## Handling User Input Requests

If agent calls `RequestUserInput` tool during execution:

```swift
let result = await RequestUserInput(prompt: "Confirm: Apply this fix?").execute()
// -> Emits UserInputRequest event
// -> Suspends loop: awaits response from user (via WebSocket)
// -> onReceive handles UserInputResponse
// -> Resumes agent run with user's input appended to history
```

Flow:
1. Agent calls tool
2. Tool emits `UserInputRequest` event to WebSocket
3. Client prompts user, collects response
4. Client sends `UserInputResponse` back via WebSocket
5. `WebSocketServer.handleUserInputResponse()` routes to awaiting agent
6. Agent loop resumes with user input in message history

## Phase 4: Finalization

After loop exits (stop signal or iteration limit):

```swift
// 1. Collect durable memory (optional)
let memoryPrompt = AgentUtilities.memorySessionPrompt
await agent.run(
    prompt: memoryPrompt,
    onEvent: { _ in }  // Silent (don't stream to user)
)
// Agent calls MemPalace tools to write diary, update graph

// 2. Persist chat
await chat.save()  // Chat metadata + all messages written to disk

// 3. Emit final event
onEvent(.agentState(.idle))  // Agent ready for next run
```

**What happens:**
- All accumulated messages (user, assistant, tool calls, results) are serialized
- Chat metadata (title, subtitle, timestamps) updated
- Entire chat persisted to `/databank/chats/metadata/` + `/databank/chats/messages/`
- Agent state reset to `.ready`
- Next user prompt starts new iteration with same agent + expanded history

## Message Structure & Serialization

### `Message` struct
```swift
struct Message: Codable {
    let uuid: String                    // Unique ID
    let runUUID: String                 // Which run generated this
    let createdAt: Date
    let model: String                   // "claude-3-5-sonnet-20241022"
    let role: String                    // "user" | "assistant"
    let text: String?                   // Message body (optional if tool calls)
    let toolCalls: [ToolCall]?          // Structured tool invocations
    let toolCallId: String?             // Links to result response
    let attachments: [ImageAttachment]? // Images, files, etc.
}
```

### `MessageData` (persistent)
Subset of Message stored to disk (excludes some transient fields).

### Provider-Specific Message Formats

**Anthropic (Streaming):**
```
ContentBlockStartEvent
  -> type: "content_block_start", index: 0, content_block: { type: "text" }
ContentBlockDeltaEvent
  -> type: "content_block_delta", delta: { type: "text_delta", text: "I'll..." }
ContentBlockDeltaEvent
  -> type: "content_block_delta", delta: { type: "text_delta", text: " help..." }
ContentBlockStartEvent
  -> type: "content_block_start", index: 1, content_block: { type: "tool_use", id, name }
ContentBlockDeltaEvent
  -> type: "content_block_delta", delta: { type: "input_json_delta", partial_json: "{" }
```

**OpenAI (Non-streaming):**
```json
{
  "choices": [
    {
      "message": {
        "role": "assistant",
        "content": "I'll check the file...",
        "tool_calls": [
          {
            "id": "call_123",
            "type": "function",
            "function": {
              "name": "read_file",
              "arguments": "{\"path\": \"...\"}"
            }
          }
        ]
      },
      "stop_reason": "tool_calls"
    }
  ]
}
```

## Context Window Management

When message history grows large:

```
History size: 180k tokens (approaching 200k context window)
├─ System prompt: 5k
├─ Tools definitions: 15k
├─ Recent messages: 50k (kept intact)
└─ Older messages: 110k (candidates for compaction)

Trigger: New prompt would exceed 80% (160k)
Action: Summarize oldest ~80 messages into dense summary
Result: Summary (~3k) replaces those 80 messages
New total: ~30k (6k system + 15k tools + 3k summary + 6k recent) = plenty of room
```

**Compaction prompt** (`AgentUtilities.compactionPrompt`):
- Takes transcript of old messages
- Produces: CONTEXT, STATE, KEY FACTS & DECISIONS, FILES & ARTIFACTS, USER PREFERENCES, UNRESOLVED & NEXT STEPS
- Replaces original messages; agent continues seamlessly

## Error Handling & Recovery

### Tool Execution Errors
- Tool raises exception → caught in loop
- Error message appended to history: "Tool failed: [error description]"
- Loop continues; agent can try different approach or inform user

### Permission Denied
- Mode rejects tool request
- Error appended: "Mode does not allow [action]. Try changing mode."
- Agent can request user escalation or retry with allowed operations

### Provider API Errors
- Network failure, rate limit, model error → caught in `provider.call()`
- Error logged; exception propagated to caller
- Chat receives error event; displayed to user
- Can retry with backoff or switch provider

### Iteration Limit Reached
- Graceful stop: agent doesn't call any more tools, just summarizes
- No error; agent knows its iteration budget

## Key Design Insights

1. **Streaming feedback** — Agent emits events as they happen; client sees thinking, tool calls, results in real-time
2. **Tool sandboxing** — Permissions evaluated per-mode; some tools (Python) run in isolated subprocess
3. **History compaction** — Solves context window pressure without losing information
4. **Suspension points** — Agent can be suspended waiting for user input; resumes with input appended
5. **Persistent iteration** — Chats persist across sessions; next prompt sees full history

## Next Steps

- **[Message Flow](/openwiki/workflows/message-flow.md)** — WebSocket and end-to-end request/response
- **[Security & Modes](/openwiki/security/modes-and-permissions.md)** — Permission evaluation details per mode
- **[Tools & Skills](/openwiki/tools-and-skills/overview.md)** — Tool protocol and implementation patterns

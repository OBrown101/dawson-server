---
type: Architecture
title: DAWSON Architecture Overview
description: High-level system design, component relationships, and how DAWSON orchestrates agents, manages state, and communicates with clients.
resource: /Sources/classes/Dawson.swift
tags: [architecture, system-design, orchestration]
---

# Architecture Overview

DAWSON is a layered, actor-based orchestration platform built on Swift 6.0 and Vapor 4. This document explains the high-level design and how major components interact.

## System Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        Client (Beakshield)                  │
│                    TLS WebSocket Connection                 │
└─────────────────────────────────────────┬───────────────────┘
                                           │
                    wss://localhost:8443/dawson
                                           │
┌─────────────────────────────────────────▼───────────────────┐
│                    Vapor HTTP Server                         │
│  ┌─────────────────────────────────────────────────────┐   │
│  │          WebSocket Server / Security Layer          │   │
│  │  ┌───────────────────────────────────────────────┐  │   │
│  │  │     Packet Router (ping, syncState, chat)    │  │   │
│  │  └───────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────┬───────────────────┘
                                           │
┌─────────────────────────────────────────▼───────────────────┐
│               DAWSON Singleton Orchestrator                  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Session Management (Chats)                  │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │  Chat UUID → Chat (user, agent, history)    │   │  │
│  │  │  Persisted to /databank/chats/              │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │     Agent Handler (Concurrent Execution)            │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │  AgentUUID → Agent (mode, model, tools)    │   │  │
│  │  │  Executor: Agent.run() with streaming      │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
         │                      │                    │
         ▼                      ▼                    ▼
    ┌─────────────┐      ┌──────────────┐   ┌──────────────┐
    │  LLM        │      │ Persistent   │   │ Tool         │
    │  Providers  │      │ Storage      │   │ Ecosystem    │
    │             │      │              │   │              │
    │ Anthropic   │      │ /databank/   │   │ File I/O     │
    │ OpenAI      │      │ /security/   │   │ Python       │
    │ Ollama      │      │ /providers/  │   │ Memory       │
    └─────────────┘      └──────────────┘   │ Web          │
                                             │ Commands     │
                                             │ MCP          │
                                             └──────────────┘
```

## Core Layers

### 1. Communication Layer

**Responsibility:** Secure client-server messaging via WebSocket

- **`WebSocketServer`** — Manages connections, routes packets by type, handles chunking for large payloads
- **`WebSocketSecurity`** — TLS certificate generation, bearer token authentication, certificate fingerprinting
- **Entry Point:** `main.swift` bootstraps Vapor with TLS config and WebSocket endpoint at `/dawson`

Key files:
- `/Sources/classes/websocket/WebSocketServer.swift`
- `/Sources/classes/websocket/WebSocketSecurity.swift`
- `/Sources/classes/websocket/WSPacket.swift`

### 2. Orchestration Layer

**Responsibility:** Session management, agent lifecycle, event routing

- **`DAWSON` singleton** — Holds active chats, routes messages to correct session, starts agent execution
- **`Chat`** — Encapsulates user session (UUID, messages, agent UUID, metadata), persists to disk
- **`AgentHandler`** — Singleton managing concurrent agent runs, tracks execution state per agent UUID

Key files:
- `/Sources/classes/Dawson.swift`
- `/Sources/classes/Chat.swift`
- `/Sources/classes/agents/AgentHandler.swift`

### 3. Agent Execution Layer

**Responsibility:** LLM interaction, tool invocation, permission checking, event emission

- **`Agent`** — Embodies execution state (mode, model, directories, tool bindings) and orchestrates a single run
- **`Agent.run()`** — Main loop: prepare messages → call provider → parse response → execute tools → iterate → finalize
- **`AgentEventStreamState`** — Captures thinking, tool calls, results as events; streams to WebSocket

Key files:
- `/Sources/classes/agents/Agent.swift`
- `/Sources/classes/agents/AgentEventStreamState.swift`
- `/Sources/classes/agents/AgentUtilities.swift`

### 4. Provider Abstraction Layer

**Responsibility:** Unified API for heterogeneous LLM backends

- **`LLMProvider` protocol** — Defines `call()` for API requests; handles response parsing, tool extraction
- **Implementations:** `AnthropicProvider`, `OpenAIProvider`, `OllamaProvider`
- **`ProviderHandler`** — Registry and factory for provider instances

Key files:
- `/Sources/classes/providers/Provider.swift`
- `/Sources/classes/providers/AnthropicProvider.swift`
- `/Sources/classes/providers/OpenAIProvider.swift`
- `/Sources/classes/providers/OllamaProvider.swift`

### 5. Capability & Tool Layer

**Responsibility:** Tool execution, permission enforcement, sandboxing

- **`Tool` protocol** — Interface for executable capabilities with input/output schemas
- **Tool categories:**
  - **File I/O:** `ReadFile`, `WriteFile`, `ReplaceInFile`, `Grep`, `Find`, `Tree`
  - **Command execution:** `RunCommand`
  - **Memory:** 15+ MemPalace operations (graph queries, diary access, etc.)
  - **Python:** `RunPythonCode`, `RunPythonScript`, `InstallPythonPackage` (sandboxed)
  - **Web:** `FetchURL`
  - **Utility:** `RequestUserInput`, `SpawnAgent`, `Speak`, `GetSessionInfo`
- **Permissions:** Evaluated per-mode via `Mode` protocol implementations

Key files:
- `/Sources/tools/protocols/Tool.swift`
- `/Sources/tools/` (all tool implementations)
- `/Sources/classes/modes/*.swift` (permission evaluation)

### 6. Storage & Persistence Layer

**Responsibility:** Durable state for chats, messages, providers, users, security artifacts

- **Chat persistence:** `/databank/chats/metadata/` (Chat metadata) + `/databank/chats/messages/` (MessageData)
- **Provider config:** `/databank/providers/metadata/` (credentials, available models, defaults)
- **User profiles:** `/databank/users/` (minimal; enhanced by MemPalace)
- **Security:** `/databank/security/` (TLS certs, auth tokens, fingerprints)
- **Skills:** `/databank/skills/` (loaded by `SkillHandler`, discovered at runtime)
- **Memory:** MemPalace graph stored separately (outside `/databank/` typically)

Key files:
- `/Sources/classes/Chat.swift` (chat/message persistence)
- `/Sources/classes/providers/Provider.swift` (provider serialization)
- `/Sources/classes/SkillHandler.swift` (skill discovery)

### 7. Cross-Cutting Concerns

#### Security & Modes
- **`Mode` protocol** — Defines permission boundaries for Egg, Fledgling, Warrior, Ultimate
- **`PermissionRequest` & `PermissionEvaluation`** — Tool execution approval flow
- **Per-mode logic:** Iteration limits, file/command restrictions, approval gating

#### Python Integration
- **`PythonEnv`** — Sets up Python 3.11 paths, environment variables, and PythonKit bridging
- **`PythonHandler`** — Manages isolated Python environments and script execution
- **`PythonSandbox`** — Sandboxing utilities for restricted code execution

#### Model Context Protocol (MCP)
- **`MCPHandler`** — Registry of external MCP servers (read-only tools from external systems)
- **`MCPServer`** — Client connection to an MCP server; lists and invokes tools
- **Integration:** Tools callable from agent via `MCPTool`

#### Memory & Knowledge
- **`MempalaceMemory`** — Wrapper for persistent knowledge graph access
- **15+ memory tools** — Graph queries, diary, room/wing management, timeline analysis

## Data Flow: Typical Chat Interaction

1. **Client sends message**
   - WebSocket packet: `type: .chatData`, payload contains user message, chat UUID

2. **WebSocketServer receives packet**
   - `onReceive()` deserializes payload into `ChatData`
   - Calls `handleChatData()` → forwards to `DAWSON.shared`

3. **DAWSON routes to chat session**
   - Resolves chat UUID or creates new chat
   - Calls `Chat.getResponse(prompt, onEvent:)`

4. **Chat creates/resolves agent and starts run**
   - Agent created with user's mode, model, directories, tools
   - Calls `Agent.run(prompt)` with streaming callback

5. **Agent execution loop iterates**
   - **Step 1:** Format conversation history + system prompt
   - **Step 2:** Call `provider.call(...)` (Anthropic/OpenAI/Ollama API)
   - **Step 3:** Parse response (content, thinking, tool calls)
   - **Step 4:** Emit `AgentEvent.content(text)` → WebSocket
   - **Step 5:** If tool calls: evaluate permissions, execute tools, emit `toolCall` + `toolResult`
   - **Step 6:** If model signaled stop or iteration limit reached, finalize; else loop

6. **Events stream to client**
   - WebSocketServer sends events as they're emitted
   - Client displays thinking, tool execution, and final content in real-time

7. **Chat persists**
   - After agent finalization, `Chat` saves all messages and metadata to disk
   - Subsequent chat loads from disk; history prepended to new run

## Key Design Patterns

### Singleton Orchestration
- **`DAWSON.shared`** — Single instance coordinating all sessions
- Simplifies state management; all chats resolvable from DAWSON
- Chat UUIDs are globally unique within DAWSON instance

### Protocol-Based Extensibility
- **`LLMProvider`** — New backends implement this protocol
- **`Tool`** — New capabilities added without modifying agent core
- **`Mode`** — Custom security policies via new Mode implementations
- Encourages loose coupling and testability

### Actor-Based Concurrency
- **`Agent`** runs in Swift actor context for thread safety
- **`AgentRunner`** actor manages per-agent execution state
- Prevents concurrent runs of the same agent; serializes tool access

### Event-Driven Streaming
- **Agent emits events** during execution (content, thinking, tool calls)
- **WebSocket streams events** in real-time to clients
- Enables responsive UX without polling

### Lazy Initialization & Optional Tools
- Agents load tools lazily; tool instances created on first access
- **Required tools** always available; **optional tools** depend on agent config
- Reduces startup time; allows per-agent customization

## State Management Across Layers

| Layer | State | Holder | Persistence |
|-------|-------|--------|-------------|
| Client | Chat history, UI state | Beakshield | In-memory + local storage |
| WebSocket | Active connections | WebSocketServer | In-memory (connections) |
| Orchestration | Active chats | DAWSON singleton | Disk (/databank/chats/) |
| Agent | Execution context (mode, model, tools) | Agent instance | Transient (in-memory) |
| Execution | Messages, thinking, tool state | Chat.messages array | Disk after finalization |
| Providers | API credentials, model lists | Provider instances | Disk (/databank/providers/) |
| Security | TLS certs, tokens | WebSocketSecurity | Disk (/databank/security/) |

## Boundaries & Responsibilities

### What DAWSON Does NOT Do
- **UI Rendering** — Delegated to Beakshield client
- **Model Training** — Uses pre-trained models from providers
- **Voice/STT** — Partially implemented in early code (not production-ready)
- **Long-running background tasks** — Planned (not yet implemented)

### What DAWSON Does Well
- **Multi-agent orchestration** — Manages concurrent chats with different modes/models
- **Secure local execution** — Permission-gated tool access per mode
- **Persistent knowledge** — MemPalace integration for long-term learning
- **Real-time communication** — WebSocket streaming for responsive UX
- **Provider abstraction** — Unified interface for multiple LLM backends

## Next Steps

- **[Agent Lifecycle & Execution](/openwiki/workflows/agent-lifecycle.md)** — Deep dive into agent.run() loop
- **[Message Flow](/openwiki/workflows/message-flow.md)** — Trace a chat request end-to-end
- **[Security & Modes](/openwiki/security/modes-and-permissions.md)** — Permission evaluation details
- **[Data & Storage](/openwiki/data-and-storage/persistence.md)** — Serialization and file layout

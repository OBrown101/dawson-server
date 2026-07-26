---
type: Guide
title: DAWSON Quickstart
description: An introduction to DAWSON's architecture, core concepts, and how to navigate the codebase for development and contribution.
tags: [architecture, guide, overview]
---

# DAWSON Quickstart

DAWSON is a self-hosted, Swift-based AI orchestration platform that provides secure agent execution, persistent memory, flexible security modes, and seamless integration with multiple LLM providers. This wiki helps developers understand the codebase, navigate key components, and contribute effectively.

## What is DAWSON?

**DAWSON** (Digital Assistant Working Safely Offline) is a multi-agent harness that:

- **Orchestrates AI agents** — Manages a persistent `DAWSON` coordinator and dedicated chat agents (Squirebots)
- **Provides secure communication** — Uses TLS-encrypted WebSocket for client-server messaging
- **Maintains persistent memory** — Integrates MemPalace for long-term knowledge management
- **Manages multiple LLM backends** — Supports Anthropic, OpenAI, and Ollama providers
- **Enforces flexible security** — Permission-aware modes (Egg, Fledgling, Warrior, Ultimate) control agent capabilities
- **Supports extensible tools & skills** — Rich tool library + Claude Skills for expert knowledge reuse
- **Integrates Python & MCP** — Direct Python environment support and Model Context Protocol for external tools

Built with **Swift 6.0** and **Vapor 4.76+**, DAWSON runs on macOS and Linux as a persistent server, typically accessed through the **Beakshield** cross-platform desktop client.

## Key Concepts at a Glance

### Agents & Chats

- **DAWSON** — Singleton persistent orchestrator coordinating the entire system
- **Squirebots** — Task-focused agents dedicated to individual chat sessions
- **Chat** — Container for messages, metadata, and conversation state (persisted to disk)
- **Agent** — Execution runtime with mode, model selection, tool access, and LLM provider bindings

→ **Learn more:** [Agent Lifecycle & Execution](/openwiki/workflows/agent-lifecycle.md)

### Security & Modes

DAWSON enforces capability-based permissions through four **modes**:

| Mode | Purpose | Iterations | Key Restrictions |
|------|---------|-----------|-------------------|
| **Egg** | Conversational only | 5 | No file/host access |
| **Fledgling** | Basic file operations | 10 | Whitelisted directories, read-only |
| **Warrior** | Full file & command access | 20 | Approval-gated commands, directory scope |
| **Ultimate** | Unrestricted autonomous work | None | Full system access |

→ **Learn more:** [Security & Modes](/openwiki/security/modes-and-permissions.md)

### LLM Providers

DAWSON abstracts provider-specific API details through a unified `LLMProvider` protocol. Supported:

- **Anthropic** — Claude models with extended thinking, vision, and structured output
- **OpenAI** — GPT-4, GPT-4o, and other models with OAuth support
- **Ollama** — Local LLM inference for private, offline use

Each provider is configured with API keys, available models, and preferred defaults.

→ **Learn more:** [Provider Architecture](/openwiki/integrations/llm-providers.md)

### Tools & Skills

- **Tools** — Executable capabilities (file I/O, command execution, memory access, Python sandboxing)
- **Skills** — Reusable expertise bundles loaded from `/databank/skills/` with YAML metadata
- **Tool Protocol** — Agents execute tools; permissions are evaluated per-mode

→ **Learn more:** [Tools & Skills](/openwiki/tools-and-skills/overview.md)

### Memory & Storage

- **Chats** — User conversations are persisted to `/databank/chats/metadata/` and `/databank/chats/messages/`
- **Providers** — API credentials and model configs stored in `/databank/providers/`
- **MemPalace** — Persistent knowledge graph for cross-conversation learning
- **Security Artifacts** — TLS certificates, auth tokens, and fingerprints in `/databank/security/`

→ **Learn more:** [Data & Storage](/openwiki/data-and-storage/persistence.md)

### WebSocket & Real-Time Messaging

Clients (Beakshield, external apps) connect via secure WebSocket at `wss://localhost:8443/dawson` with token-based authentication. Packet types include chat data, agent events (thinking, tool calls, results), and user input requests.

→ **Learn more:** [WebSocket Communication](/openwiki/integrations/websocket.md)

## Repository Structure

```
/Sources
  /classes
    /agents           ← Agent execution, event streaming, task registry
    /modes            ← EggMode, FledglingMode, WarriorMode, UltimateMode
    /providers        ← LLMProvider implementations (Anthropic, OpenAI, Ollama)
    /python           ← Python environment, sandboxing, PythonKit integration
    /mcp              ← Model Context Protocol client & tool bridging
    /websocket        ← WebSocket server, security, packet handling
    Chat.swift        ← Chat persistence & session management
    Dawson.swift      ← Singleton orchestrator
    SkillHandler.swift ← Skill discovery & loading
    UserHandler.swift ← User profile & session management
    main.swift        ← Server bootstrap & Vapor setup

  /enums             ← ModeType, CommandClass, MsgSource, PermissionDecision, etc.
  /structs           ← Message, Chat data, LLMModel, Permission structures, etc.
  /extensions        ← Date, String utilities
  /tools             ← Extensible tool implementations
    /cmdTools         ← Command execution
    /fileTools        ← File I/O (read, write, grep, find, tree)
    /memoryTools      ← MemPalace integration (15+ memory operations)
    /pythonTools      ← Python package install, script execution, sandboxing
    /webTools         ← URL fetching
    Protocols/        ← Tool, PermissionAware, ChatAware interfaces

  /souls             ← Agent personality/behavior modules (DawsonPrimarySoul, SquirebotPrimarySoul)

/databank            ← Runtime data directory (users, chats, providers, skills, memory, security)

/skills              ← Skill definitions (migrate-wiki-to-okf, write-connector)

Package.swift        ← Swift Package dependencies (Vapor, AnyCodable, PythonKit, MCP SDK)
```

## Main Entry Points for Development

### Server Bootstrap
- **`main.swift`** — Initializes Vapor HTTP server, TLS setup, WebSocket endpoint registration
- **`Dawson.swift`** — Singleton coordinator managing chats, agents, and routing
- **`ServerSettings.swift`** — Global configuration (debug mode, logging, feature flags)

### Request Handling Flow
1. **WebSocket packet arrives** → `WebSocketServer.onReceive()`
2. **Packet routed by type** → e.g., `handleChatData()` for new user messages
3. **Chat resolved** → `DAWSON.getChat()` finds or creates session
4. **Agent execution starts** → `Chat.getResponse()` dispatches to `Agent.run()`
5. **Events stream back** → Agent emits `content`, `thinking`, `toolCall`, `toolResult`, etc.
6. **WebSocket packets sent** → Client receives real-time updates

→ **Learn more:** [Message Flow & Architecture](/openwiki/workflows/message-flow.md)

### Agent Execution Loop
1. **Message preparation** — History, tools, permissions context gathered
2. **Provider call** — Formatted request sent to LLM (Anthropic, OpenAI, Ollama)
3. **Response parsing** — Content, thinking, tool calls extracted
4. **Tool execution** — Permissions evaluated, tools run in sandbox if needed
5. **Loop** — Iterate until model stops or iteration limit reached
6. **Finalization** — Messages persisted, events emitted

→ **Learn more:** [Agent Lifecycle & Execution](/openwiki/workflows/agent-lifecycle.md)

## Key Files to Understand First

| File | Purpose | Read When |
|------|---------|-----------|
| `Sources/classes/Dawson.swift` | Core orchestrator & session management | Understanding server architecture |
| `Sources/classes/Chat.swift` | Chat lifecycle, message persistence, agent dispatch | Working on chat features |
| `Sources/classes/agents/Agent.swift` | Agent state, tool bindings, execution loop | Understanding agent behavior |
| `Sources/classes/websocket/WebSocketServer.swift` | Client message routing & packet handling | Working on client communication |
| `Sources/classes/modes/Mode.swift` + implementations | Permission evaluation per mode | Implementing or debugging security |
| `Sources/classes/providers/Provider.swift` + implementations | LLM provider abstractions | Adding a new provider or debugging model calls |
| `Sources/tools/` | Tool implementations | Adding new capabilities |
| `Package.swift` | Dependencies & build configuration | Understanding external libraries |

## Common Development Tasks

### Adding a New Tool
1. Create a new file in `/Sources/tools/` implementing the `Tool` protocol
2. Define input/output schemas and execution logic
3. Register in agent's `optionalTools` list
4. Test with sample prompts

→ **Details:** [Tools & Skills](/openwiki/tools-and-skills/overview.md#extending-tools)

### Changing Security or Permissions
1. Modify the relevant mode file (`/Sources/classes/modes/*.swift`)
2. Update `evaluateRequests()` or `guardRequests()` logic
3. Ensure changes propagate through `Agent.checkPermissions()`
4. Test across Egg → Ultimate mode transitions

→ **Details:** [Security & Modes](/openwiki/security/modes-and-permissions.md)

### Adding a New LLM Provider
1. Create new `struct` implementing `LLMProvider` protocol in `/Sources/classes/providers/`
2. Implement `call()` method for API requests, response parsing, tool handling
3. Register in `Provider.provider(for:)` factory
4. Add provider-specific tests

→ **Details:** [Provider Architecture](/openwiki/integrations/llm-providers.md)

### Debugging Agent Behavior
- Check agent `mode`, `model`, and available `tools`
- Inspect tool execution logs in `/databank/` or console output
- Review `Chat` message history persisted to disk
- Enable `#if DEBUG` logging in `Agent.swift`

## Testing & Local Development

No dedicated test suite currently exists. Manual integration testing is performed:

1. Start DAWSON server: `swift run DAWSON`
2. Connect Beakshield client with auth token
3. Send messages through chat UI
4. Inspect `/databank/` for persisted data
5. Check console for debug output

## Documentation Organization

- **[Architecture](/openwiki/architecture/)** — System design, component roles, data models
- **[Workflows](/openwiki/workflows/)** — Agent lifecycle, message flow, real-time streaming
- **[Security](/openwiki/security/)** — Modes, permission evaluation, capabilities matrix
- **[Tools & Skills](/openwiki/tools-and-skills/)** — Tool protocol, skill framework, examples
- **[Data & Storage](/openwiki/data-and-storage/)** — Persistence, serialization, file layout
- **[Integrations](/openwiki/integrations/)** — WebSocket, LLM providers, Python, MCP
- **[Design Decisions](/openwiki/design-decisions.md)** — Why key architectures were chosen

## Next Steps

**New to the codebase?** Start with [Architecture Overview](/openwiki/architecture/overview.md), then dive into [Agent Lifecycle](/openwiki/workflows/agent-lifecycle.md).

**Want to extend DAWSON?** Check [Adding Tools](/openwiki/tools-and-skills/overview.md) or [Provider Integration](/openwiki/integrations/llm-providers.md).

**Debugging an issue?** Use [Troubleshooting](/openwiki/troubleshooting.md) or review relevant [Workflow](/openwiki/workflows/) documentation.

**Contributing?** Read the repository [INSTRUCTIONS.md](/openwiki/INSTRUCTIONS.md) for guidelines, then reference [Design Decisions](/openwiki/design-decisions.md) before proposing major changes.

---

## Backlog

- **Beakshield client architecture** — Cross-platform Kotlin Multiplatform app (separate repo)
- **Royal Decrees system** — Planned for persistent behavioral rules
- **Voice interaction** — STT/TTS pipeline (partially implemented in early DAWSON versions)
- **Page orchestration** — Sub-agent hierarchy and spawning workflows
- **Detailed testing guide** — Unit and integration test patterns

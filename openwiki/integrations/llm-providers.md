---
type: Integration
title: LLM Provider Integration
description: How DAWSON abstracts and integrates with multiple LLM backends (Anthropic, OpenAI, Ollama) and the provider protocol for extensibility.
resource: /Sources/classes/providers/
tags: [integration, llm, providers, api]
---

# LLM Provider Integration

DAWSON abstracts LLM interactions through a unified provider protocol, allowing agents to seamlessly switch between different backends. This document explains the architecture and how to add new providers.

## Provider Abstraction

### LLMProvider Protocol

All providers implement this protocol:

```swift
protocol LLMProvider {
    func send(
        messages: [Message],
        model: LLMModel,
        tools: [Tool],
        useThinking: Bool,
        contextWindow: Int32,
        onUpdate: @Sendable @escaping (ProviderResponse) async -> Void
    ) async -> ProviderResponse
}
```

**Responsibilities:**
1. Format agent messages per provider API spec
2. Send request to provider's endpoint
3. Handle streaming response chunks
4. Parse response into structured data (content, thinking, tool calls)
5. Call `onUpdate` callback for each chunk (streaming)
6. Return final `ProviderResponse`

### Model Data Structure

```swift
struct LLMModel: Codable {
    let id: String                   // Model identifier (e.g., "claude-3-5-sonnet-20241022")
    let name: String                 // Display name
    let provider: ProviderClient.ProviderType  // Which provider
    let contextWindow: Int32         // Token limit
    let costPer1kInput: Double       // Pricing
    let costPer1kOutput: Double
}
```

### Provider Response

```swift
struct ProviderResponse: Sendable {
    let createdAt: String           // Timestamp or ID
    let providerType: ProviderClient.ProviderType
    let model: String               // Model used
    let content: String             // Text response
    let thinking: String?           // Optional thinking content
    let toolCalls: [ToolCall]?      // Structured tool invocations
    let stopReason: String?         // "end_turn", "tool_use", etc.
    let usage: TokenUsage?          // Input/output token counts
}
```

## Supported Providers

### Anthropic (Claude)

**Location:** `/Sources/classes/providers/AnthropicProvider.swift`

**Configuration:**
```json
{
  "type": "anthropic",
  "apiKey": "sk-ant-...",
  "availableModels": [
    {
      "id": "claude-3-5-sonnet-20241022",
      "name": "Claude 3.5 Sonnet",
      "provider": "anthropic",
      "contextWindow": 200000,
      "costPer1kInput": 3.00,
      "costPer1kOutput": 15.00
    }
  ]
}
```

**API Details:**
- **Endpoint:** `https://api.anthropic.com/v1/messages`
- **Authentication:** Bearer token in `x-api-key` header
- **Streaming:** Server-sent events (SSE) with `stream: true`
- **Tools:** Defined via `tools` array; model selects with `tool_choice: { type: "auto" }`
- **Thinking:** Supported via `thinking` block (currently disabled pending implementation)

**Request Format:**
```json
{
  "model": "claude-3-5-sonnet-20241022",
  "max_tokens": 8192,
  "system": "You are a helpful assistant...",
  "messages": [
    {"role": "user", "content": "Help me debug..."},
    {"role": "assistant", "content": "I'll help. Let me check..."},
    {"role": "user", "content": "Tool result: [...]"}
  ],
  "tools": [
    {
      "name": "read_file",
      "description": "Read a file",
      "input_schema": {
        "type": "object",
        "properties": {
          "path": {"type": "string"}
        }
      }
    }
  ],
  "tool_choice": {"type": "auto"},
  "stream": true
}
```

**Response Streaming:**
```
event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"text"}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"I'll"}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" help"}}

event: content_block_start
data: {"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"tool_1","name":"read_file"}}

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\"p"}}
```

**Tool Call Parsing:**
```swift
// Anthropic sends tool use blocks like:
{
  "type": "tool_use",
  "id": "tool_1",
  "name": "read_file",
  "input": {"path": "/path/to/file.txt"}
}

// Parsed into ToolCall:
ToolCall(id: "tool_1", name: "read_file", args: {"path": "/path/to/file.txt"})
```

### OpenAI (GPT-4, GPT-4o)

**Location:** `/Sources/classes/providers/OpenAIProvider.swift`

**Configuration:**
```json
{
  "type": "openai",
  "apiKey": "sk-...",
  "useOAuth": true,
  "availableModels": [
    {
      "id": "gpt-4o",
      "name": "GPT-4o",
      "provider": "openai",
      "contextWindow": 128000,
      "costPer1kInput": 5.00,
      "costPer1kOutput": 15.00
    }
  ]
}
```

**API Details:**
- **Endpoint:** `https://api.openai.com/v1/chat/completions`
- **Authentication:** Bearer token in `Authorization` header
- **Streaming:** Server-sent events with `stream: true`
- **Tools:** Function calling via `tools` array; model selects with `tool_choice: "auto"`
- **Vision:** Supports images in message content (for GPT-4o)

**Request Format:**
```json
{
  "model": "gpt-4o",
  "messages": [
    {"role": "system", "content": "You are helpful..."},
    {"role": "user", "content": "Help me debug..."},
    {"role": "assistant", "content": "I'll check...", "tool_calls": [...]},
    {"role": "tool", "tool_call_id": "call_1", "content": "File contents..."}
  ],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "read_file",
        "description": "Read a file",
        "parameters": {
          "type": "object",
          "properties": {
            "path": {"type": "string"}
          }
        }
      }
    }
  ],
  "tool_choice": "auto",
  "stream": true
}
```

**Response Streaming:**
```json
{"choices":[{"delta":{"content":"I'll"},"index":0}]}
{"choices":[{"delta":{"content":" help"},"index":0}]}
{"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"name":"read_file","arguments":"{\"pa"}}]},"index":0}]}
```

### Ollama (Local LLMs)

**Location:** `/Sources/classes/providers/OllamaProvider.swift`

**Configuration:**
```json
{
  "type": "ollama",
  "apiKey": "",
  "availableModels": [
    {
      "id": "mistral:7b",
      "name": "Mistral 7B",
      "provider": "ollama",
      "contextWindow": 32768,
      "costPer1kInput": 0.00,
      "costPer1kOutput": 0.00
    }
  ]
}
```

**API Details:**
- **Endpoint:** `http://localhost:11434/api/generate` (local inference)
- **No authentication:** Local-only, no API keys
- **Streaming:** Line-delimited JSON
- **Tools:** Limited support (most local models don't support function calling)
- **Privacy:** All processing happens locally; no external API calls

**Request Format:**
```json
{
  "model": "mistral:7b",
  "prompt": "System: You are helpful...\n\nUser: Help me debug...",
  "stream": true
}
```

**Response Streaming:**
```json
{"response":"I'll","done":false}
{"response":" help","done":false}
{"response":"","done":true,"total_duration":2500000000}
```

## Provider Selection Flow

```
User sends message with model preference
    │
    ├─ Agent.model = user-selected LLM
    │
    ├─ Provider.provider(for: model.provider)
    │  ├─ .anthropic → AnthropicProvider()
    │  ├─ .openai → OpenAIProvider()
    │  └─ .ollama → OllamaProvider()
    │
    ├─ Agent.run() calls:
    │  provider.send(messages, model, tools, thinking, contextWindow)
    │
    └─ Provider executes request & returns ProviderResponse
```

## Adding a New Provider

### Step 1: Implement LLMProvider Protocol

Create `/Sources/classes/providers/CustomProvider.swift`:

```swift
import Foundation

final class CustomProvider: LLMProvider {
    func send(
        messages: [Message],
        model: LLMModel,
        tools: [Tool],
        useThinking: Bool,
        contextWindow: Int32,
        onUpdate: @Sendable @escaping (ProviderResponse) async -> Void
    ) async -> ProviderResponse {
        var response = ProviderResponse(
            createdAt: "",
            providerType: .custom,  // Add to ProviderType enum
            model: model.name,
            content: ""
        )
        
        // 1. Format messages per provider spec
        let payload = formatMessages(messages, model, tools)
        
        // 2. Send request
        let stream = try await httpClient.stream(endpoint: "https://api.custom.com/chat", payload: payload)
        
        // 3. Parse streaming response
        for try await chunk in stream {
            let parsed = parseChunk(chunk)
            response.content += parsed.content
            
            if let toolCall = parsed.toolCall {
                response.toolCalls = (response.toolCalls ?? []) + [toolCall]
            }
            
            // 4. Emit update
            await onUpdate(response)
        }
        
        return response
    }
    
    private func formatMessages(_ messages: [Message], _ model: LLMModel, _ tools: [Tool]) -> [String: Any] {
        // Format per provider's API spec
        return [:]
    }
    
    private func parseChunk(_ chunk: Data) -> (content: String, toolCall: ToolCall?) {
        // Parse provider-specific chunk format
        return ("", nil)
    }
}
```

### Step 2: Register Provider

In `Provider.swift`:

```swift
enum ProviderType: String, Codable {
    case anthropic
    case openai
    case ollama
    case custom  // Add new type
}

static func provider(for type: ProviderClient.ProviderType) -> LLMProvider {
    switch type {
    case .ollama:
        return OllamaProvider()
    case .openai:
        return OpenAIProvider()
    case .anthropic:
        return AnthropicProvider()
    case .custom:
        return CustomProvider()  // Add case
    }
}
```

### Step 3: Test

```swift
let provider = CustomProvider()
let model = LLMModel(id: "custom-model", name: "Custom", provider: .custom, contextWindow: 8000)

let response = await provider.send(
    messages: [Message(role: "user", text: "Hello")],
    model: model,
    tools: [],
    useThinking: false,
    contextWindow: 8000,
    onUpdate: { print($0.content) }
)

assert(response.content.count > 0)
```

## Tool Schema Transformation

Each provider has a different tool schema format:

### Anthropic Format
```swift
extension Tool {
    func anthropicSchema() -> [String: Any] {
        return [
            "name": name,
            "description": description,
            "input_schema": [
                "type": "object",
                "properties": inputSchema.properties.mapValues { schema in
                    return ["type": schema.type, "description": schema.description]
                },
                "required": inputSchema.required
            ]
        ]
    }
}
```

Result:
```json
{
  "name": "read_file",
  "description": "Read a file",
  "input_schema": {
    "type": "object",
    "properties": {
      "path": {"type": "string", "description": "File path"}
    },
    "required": ["path"]
  }
}
```

### OpenAI Format
```swift
extension Tool {
    func openaiSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": inputSchema.properties.mapValues { schema in
                        return ["type": schema.type, "description": schema.description]
                    },
                    "required": inputSchema.required
                ]
            ]
        ]
    }
}
```

Result:
```json
{
  "type": "function",
  "function": {
    "name": "read_file",
    "description": "Read a file",
    "parameters": {
      "type": "object",
      "properties": {
        "path": {"type": "string", "description": "File path"}
      },
      "required": ["path"]
    }
  }
}
```

## Error Handling

### API Errors
- Rate limit (429) → Retry with exponential backoff
- Auth error (401) → Log error, fall back to alternative provider
- Server error (5xx) → Retry, then notify user
- Network error → Timeout after 30s, retry

### Tool Definition Errors
- Tool schema invalid per provider → Skip tool, log error
- Tool name conflicts → Use unique prefix

### Model Not Available
- Requested model not in provider's list → Use default model
- All models unavailable → Error to user

## Performance Considerations

### Streaming
- **Latency:** First token appears in ~500-2000ms (depends on provider)
- **Throughput:** 50-500 tokens/second
- **Chunking:** Each delta event is one update callback

### Token Counting
- **Pre-request:** Estimate tokens (rough ~4 chars per token)
- **Post-request:** Use provider's token count from response
- **Cost tracking:** Multiply by rate; log for billing/monitoring

### Provider Selection Strategy
1. **Latency-critical:** Use Ollama (local, instant)
2. **Quality-critical:** Use Anthropic or OpenAI
3. **Cost-critical:** Use Ollama or OpenAI budget tier
4. **Multi-modal:** Use OpenAI (GPT-4o with vision)

## Future Providers

Candidates for integration:
- **Claude API (Bedrock)** — AWS managed Claude
- **Google Gemini** — via Vertex AI
- **Cohere** — Commercial API
- **HuggingFace Inference** — Open model hosting
- **Groq** — Ultra-fast inference
- **Together AI** — Distributed inference

## Next Steps

- **[Agent Lifecycle](/openwiki/workflows/agent-lifecycle.md)** — How providers are called during execution
- **[Tools & Skills](/openwiki/tools-and-skills/overview.md)** — Tool integration with providers
- **[Message Flow](/openwiki/workflows/message-flow.md)** — End-to-end request/response

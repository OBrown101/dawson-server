---
type: Data
title: Data & Storage Persistence
description: How DAWSON persists chats, messages, provider configurations, users, skills, and security artifacts to disk in `/databank/`.
resource: /Sources/classes/Chat.swift
tags: [persistence, storage, serialization, databank]
---

# Data & Storage Persistence

DAWSON persists all state to the local filesystem under `/databank/`. This document explains the directory structure, serialization format, and how each data type is loaded and saved.

## Directory Structure

```
/databank/
├── chats/
│   ├── metadata/           # Chat metadata (UUID.json files)
│   ├── messages/           # Chat message histories
│   │   ├── chat-uuid-1/    # Messages for specific chat
│   │   └── chat-uuid-2/
│   └── ...
├── providers/
│   └── metadata/           # LLM provider configurations
├── users/
│   └── metadata/           # User profiles (minimal; enhanced by MemPalace)
├── security/
│   ├── fullchain.pem       # TLS certificate
│   ├── privkey.pem         # TLS private key
│   ├── auth-token.txt      # Bearer token for WebSocket
│   └── auth-fingerprint.txt # Certificate fingerprint for Beakshield
├── skills/
│   └── <skillname>/        # Skill manifests (loaded at runtime)
│       └── SKILL.md
├── agents/                 # Agent metadata (metadata/ + history/)
└── [logs/]                 # Optional: Debug/activity logs
```

## Chat Persistence

### Chat Metadata

**Location:** `/databank/chats/metadata/<chat-uuid>.json`

**Structure:**
```json
{
  "uuid": "chat-abc-123",
  "userUUID": "user-alice",
  "agentUUID": "agent-primary",
  "title": "Swift Concurrency Help",
  "subtitle": "Actor model implementation",
  "updatedTimestamp": 1715867543000
}
```

**Fields:**
- `uuid` — Unique identifier for this chat
- `userUUID` — User who owns the chat
- `agentUUID` — Agent assigned to this chat
- `title` — User-set topic (editable)
- `subtitle` — Auto-generated current discussion topic
- `updatedTimestamp` — Last modification time (epoch millis)

### Chat Messages

**Location:** `/databank/chats/messages/<chat-uuid>.json`

**Structure:**
```json
[
  {
    "uuid": "msg-1",
    "runUUID": "run-456",
    "createdAt": "2026-06-15T10:30:00Z",
    "model": "claude-3-5-sonnet-20241022",
    "role": "user",
    "text": "Help me debug this Swift error",
    "toolCallId": null,
    "toolCalls": null,
    "attachments": null
  },
  {
    "uuid": "msg-2",
    "runUUID": "run-456",
    "createdAt": "2026-06-15T10:30:15Z",
    "model": "claude-3-5-sonnet-20241022",
    "role": "assistant",
    "text": "I'll help you debug. Let me first check the error...",
    "toolCallId": null,
    "toolCalls": [
      {
        "id": "tool-call-1",
        "name": "read_file",
        "args": {"path": "/Users/alice/project/main.swift"}
      }
    ],
    "attachments": null
  },
  {
    "uuid": "msg-3",
    "runUUID": "run-456",
    "createdAt": "2026-06-15T10:30:20Z",
    "model": "claude-3-5-sonnet-20241022",
    "role": "user",
    "text": "/Users/alice/project/main.swift:\n[16 lines of file content]",
    "toolCallId": "tool-call-1",
    "toolCalls": null,
    "attachments": null
  }
]
```

**Fields:**
- `uuid` — Unique message ID
- `runUUID` — Which agent execution generated this
- `createdAt` — ISO8601 timestamp
- `model` — Model that generated content (for assistant messages)
- `role` — `"user"` or `"assistant"`
- `text` — Message body
- `toolCallId` — If this is a tool result, links to the tool call it answers
- `toolCalls` — If assistant called tools, array of structured calls
- `attachments` — Images or other attachments

### Loading & Saving Chats

**Load (at startup):**
```swift
// Chat.loadAllChats() - called during DAWSON initialization
static func loadAllChats() -> [Chat] {
    let chatsDir = chatsMetadataDirectory
    var chats: [Chat] = []
    
    for file in fileManager.contentsOfDirectory(at: chatsDir) {
        if file.pathExtension == "json" {
            // Decode Chat metadata
            let chat = try? JSONDecoder().decode(Chat.self, from: readFile(file))
            
            // Load associated messages
            if let chat = chat {
                let messagesFile = chatsMessagesDirectory.appendingPathComponent("\(chat.uuid).json")
                chat.messages = try? JSONDecoder().decode([MessageData].self, from: readFile(messagesFile))
            }
            
            chats.append(chat)
        }
    }
    
    return chats
}
```

**Save (after agent finalization):**
```swift
// Chat.save() - called after Chat.getResponse() completes
public func save() throws {
    // 1. Encode and write metadata
    let metadataEncoder = JSONEncoder()
    metadataEncoder.outputFormatting = .prettyPrinted
    let metadataData = try metadataEncoder.encode(self)
    let metadataPath = Chat.chatsMetadataDirectory
        .appendingPathComponent("\(uuid).json")
    try metadataData.write(to: metadataPath)
    
    // 2. Encode and write messages
    let messagesEncoder = JSONEncoder()
    messagesEncoder.outputFormatting = .prettyPrinted
    let messagesData = try messagesEncoder.encode(messages)
    let messagesPath = Chat.chatsMessagesDirectory
        .appendingPathComponent("\(uuid).json")
    try messagesData.write(to: messagesPath)
}
```

## Provider Configuration Persistence

### Provider Metadata

**Location:** `/databank/providers/metadata/<provider-type>.json`

**Structure:**
```json
{
  "type": "anthropic",
  "apiKey": "sk-ant-...",
  "useOAuth": false,
  "availableModels": [
    {
      "id": "claude-3-5-sonnet-20241022",
      "name": "Claude 3.5 Sonnet",
      "provider": "anthropic",
      "contextWindow": 200000,
      "costPer1kInput": 3.00,
      "costPer1kOutput": 15.00
    }
  ],
  "preferredModelIDs": ["claude-3-5-sonnet-20241022"],
  "defaultModelID": "claude-3-5-sonnet-20241022",
  "updatedTimestamp": 1715867543000
}
```

**Fields:**
- `type` — Provider type (anthropic, openai, ollama)
- `apiKey` — API credential (encrypted in production; plaintext in development)
- `useOAuth` — Whether this provider uses OAuth instead of API keys
- `availableModels` — List of models available from this provider
- `preferredModelIDs` — User's preferred models (used for selection UI)
- `defaultModelID` — Default model when none specified
- `updatedTimestamp` — Last updated

### Provider Lifecycle

**Load (at startup):**
```swift
// ProviderHandler.loadProviders()
static func loadProviders() -> [ProviderClient.ProviderType: Provider] {
    var providers: [ProviderClient.ProviderType: Provider] = [:]
    
    let providersDir = Provider.providersMetadataDirectory
    
    for file in fileManager.contentsOfDirectory(at: providersDir) {
        if let provider = try? JSONDecoder().decode(Provider.self, from: readFile(file)) {
            providers[provider.type] = provider
        }
    }
    
    return providers
}
```

**Save (after provider configuration changes):**
```swift
// ProviderHandler.saveProvider(_:)
static func saveProvider(_ provider: Provider) throws {
    let filename = provider.type.rawValue + ".json"
    let path = providersMetadataDirectory.appendingPathComponent(filename)
    
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try encoder.encode(provider)
    try data.write(to: path)
}
```

## User Profiles

### User Metadata

**Location:** `/databank/users/metadata/<user-uuid>.json`

**Structure:**
```json
{
  "uuid": "user-alice",
  "displayName": "Alice Chen",
  "defaultMode": "warrior",
  "defaultProvider": "anthropic",
  "defaultModel": "claude-3-5-sonnet-20241022",
  "preferences": {
    "theme": "dark",
    "defaultWorkspace": "/Users/alice/Projects",
    "notificationsEnabled": true
  },
  "updatedTimestamp": 1715867543000
}
```

**Fields:**
- `uuid` — Unique user identifier
- `displayName` — Human-readable name
- `defaultMode` — Default security mode for new chats
- `defaultProvider` — Preferred LLM provider
- `defaultModel` — Preferred model
- `preferences` — User customizations (extensible JSON)
- `updatedTimestamp` — Last updated

## Security Artifacts

### TLS Certificates & Keys

**Location:**
- `/databank/security/fullchain.pem` — TLS certificate
- `/databank/security/privkey.pem` — TLS private key

**Generated at startup if not present:**
```swift
// WebSocketSecurity.setup()
if !FileManager.default.fileExists(atPath: certPath.path) {
    // Generate self-signed certificate valid for 10 years
    let _ = try runAndCapture("openssl", [
        "req", "-x509", "-newkey", "rsa:4096",
        "-keyout", keyPath.path,
        "-out", certPath.path,
        "-days", "3650",
        "-nodes",
        "-subj", "/CN=DAWSON Local"
    ])
}
```

### Authentication Token

**Location:** `/databank/security/auth-token.txt`

**Format:** 64-character hex string (256 bits)

**Generated at startup if not present:**
```swift
if !FileManager.default.fileExists(atPath: tokenPath.path) {
    let token = try runAndCapture("openssl", ["rand", "-hex", "32"])
        .trimmingCharacters(in: .whitespacesAndNewlines)
    try token.write(to: tokenPath, atomically: true, encoding: .utf8)
}
```

**Usage:** Clients provide as Bearer token in WebSocket authentication:
```
Authorization: Bearer <token-from-auth-token.txt>
```

### Certificate Fingerprint

**Location:** `/databank/security/auth-fingerprint.txt`

**Format:** SHA-256 fingerprint of certificate

**Purpose:** Clients (Beakshield) verify certificate authenticity when connecting

## Skills Directory

### Structure

**Location:** `/databank/skills/<skillname>/`

```
/databank/skills/
├── migrate-wiki-to-okf/
│   ├── SKILL.md           # Manifest + content
│   └── [supporting files]
└── write-connector/
    ├── SKILL.md
    └── [supporting files]
```

### Skill Manifest Format

**SKILL.md:**
```markdown
---
name: migrate-wiki-to-okf
author: Ethan Brown
version: 1.0
tags: [wiki, okf, documentation]
description: Complete instructions for migrating an existing wiki to OKF format
---

# Migrate Wiki to OKF

[Detailed content, examples, step-by-step instructions...]
```

**Discovery:** `SkillHandler.loadSkills()` scans at startup; parsed on demand

## Serialization Formats

### JSON Encoding

All data structures use standard `Codable` protocol:

```swift
struct Chat: Codable {
    // Encoder produces: { "uuid": "...", "userUUID": "...", ... }
    enum CodingKeys: String, CodingKey {
        case uuid
        case userUUID
        case agentUUID
        case title
        case subtitle
        case updatedTimestamp
    }
}
```

### Dates

Dates encoded as ISO8601 strings:
```json
{ "createdAt": "2026-06-15T10:30:00Z" }
```

Decoded via `DateFormatter` configured for ISO8601.

### AnyCodable for Flexible Fields

Preferences and metadata that don't have fixed schemas use `AnyCodable`:

```json
{
  "preferences": {
    "customKey": "anyValue",
    "nested": { "data": [1, 2, 3] }
  }
}
```

## Transaction Safety

### Atomic Writes

Each save operation uses `write(atomically:)` to prevent corruption:

```swift
try jsonData.write(to: path, atomically: true, encoding: .utf8)
```

This writes to a temporary file, then atomically renames to final path.

### Loading Resilience

Corrupt files are skipped; valid chats/providers loaded:

```swift
for file in files {
    if let chat = try? JSONDecoder().decode(Chat.self, from: readFile(file)) {
        chats.append(chat)
    } else {
        print("Warning: Failed to load chat from \(file.path)")
        // Continue; don't crash
    }
}
```

## Backup & Recovery

### Manual Backups

Users can back up `/databank/` directory:
```bash
# Backup all chats, providers, security config
cp -r ~/DAWSON/databank ~/DAWSON/databank.backup
```

### Recovery

Restore from backup:
```bash
# Restore all state
rm -rf ~/DAWSON/databank
cp -r ~/DAWSON/databank.backup ~/DAWSON/databank
```

### Future: Automated Backups

Could implement:
- Daily snapshot to S3/cloud
- Versioned chat history
- Diff-based incremental backups

## File Size Considerations

| Data Type | Typical Size | Growth |
|-----------|--------------|--------|
| Chat metadata | 1 KB | 1 KB per chat |
| Message history | 100 KB | ~1 MB per 100 messages |
| Provider config | 5 KB | Fixed per provider |
| User profile | 2 KB | Fixed per user |
| Security certs | 5 KB | Fixed once generated |
| Skills | 10–50 KB | Per skill manifest |

**Example:** User with 100 chats, ~1000 messages total:
```
100 chats × 1 KB = 100 KB
1000 messages × 100 KB average = 100 MB
Providers (3) × 5 KB = 15 KB
Total: ~100 MB
```

## Access Patterns

### Reads
- **At startup:** Load all chats (metadata) + providers + users
- **Per request:** Load specific chat's messages (on-demand)

### Writes
- **After agent run:** Save updated chat + all messages
- **On config change:** Save provider or user settings
- **On skill update:** Update skill manifest

## Future: Database Optimization

Currently: Simple JSON files on disk

Possible improvements:
- **SQLite** — Efficient queries, indexing
- **Streaming** — Load messages incrementally for large chats
- **Compression** — Gzip old chat histories
- **Encryption** — Encrypt sensitive data at rest

## Next Steps

- **[Agent Lifecycle](/openwiki/workflows/agent-lifecycle.md)** — How chats and messages are populated
- **[Architecture Overview](/openwiki/architecture/overview.md)** — System-wide state management
- **[Message Flow](/openwiki/workflows/message-flow.md)** — WebSocket to persistence flow

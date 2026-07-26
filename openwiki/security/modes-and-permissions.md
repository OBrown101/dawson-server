---
type: Security
title: Security Modes & Permission Evaluation
description: How DAWSON enforces capability-based security through four permission modes (Egg, Fledgling, Warrior, Ultimate) and evaluates tool access per mode.
resource: /Sources/classes/modes/
tags: [security, permissions, authorization, modes]
---

# Security Modes & Permission Evaluation

DAWSON enforces fine-grained, capability-based security through four **modes** that control what agents can do. This document explains each mode, the permission evaluation flow, and how to extend or customize permissions.

## Mode Hierarchy

```
┌───────────────────────────────────────────────────────────────┐
│  ULTIMATE (Unrestricted)                                      │
│  └─ Full system access, no approval gates, unlimited loops    │
├───────────────────────────────────────────────────────────────┤
│  WARRIOR (Restricted Autonomous)                              │
│  └─ Workspace I/O free, external reads require approval       │
│    └─ Approval gate: installs, harness changes, external I/O  │
├───────────────────────────────────────────────────────────────┤
│  FLEDGLING (Limited Safe)                                     │
│  └─ Whitelisted directories only, read-only by default        │
│    └─ Write requires explicit permission per operation        │
├───────────────────────────────────────────────────────────────┤
│  EGG (Conversational Only)                                    │
│  └─ No file/command/install access; chat & memory tools only │
└───────────────────────────────────────────────────────────────┘
```

## Capability Matrix

| Mode | File Read | File Write | Commands | Python Install | Web | Delegate | Iteration Limit | Approval Gate |
|------|-----------|-----------|----------|----------------|-----|----------|-----------------|---------------|
| **Egg** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ∞ | N/A |
| **Fledgling** | ✅ Whitelist | ✅ Whitelist | 🟡 Safe | 🟡 Limited | ❌ | ❌ | 10 | Per-operation |
| **Warrior** | ✅ Workspace | ✅ Workspace | ✅ Scoped | ✅ Sandboxed | ✅ | ✅ | 400 | Install/Harness |
| **Ultimate** | ✅ Any | ✅ Any | ✅ Any | ✅ Any | ✅ | ✅ | None | None |

## Mode Descriptions

### EGG Mode
**Use Case:** Initial chat, learning about the system, conversational assistance

- **Conversation:** Full LLM access; can think, reason, discuss
- **Memory tools:** Can read/write MemPalace diary and knowledge graph
- **File access:** ❌ Cannot read or write files
- **Commands:** ❌ Cannot execute shell commands
- **Python:** ❌ Cannot run Python code
- **Delegation:** ❌ Cannot spawn other agents
- **Iteration limit:** None (can loop indefinitely if model allows)
- **Approval gate:** None (all actions are inherently safe)

**Implementation:** `/Sources/classes/modes/EggMode.swift`

All permission requests are denied with specific reason messages per action type. The `guardRequests()` method throws `ModePermissionError.forbidden` for any non-conversational action.

### FLEDGLING Mode
**Use Case:** Early exploration, limited automation, learning mode

- **File access:** ✅ Can read and write to whitelisted directories only
- **Commands:** 🟡 Only "safe" pre-approved commands (e.g., `ls`, `pwd`, `cat`)
- **Python:** 🟡 Can run limited Python packages; dangerous packages blocked
- **Iteration limit:** 10 iterations (prevents runaway loops)
- **Approval gate:** Per-operation approval required for directory/command escalation

**Implementation:** `/Sources/classes/modes/FledglingMode.swift`

Directory whitelist is configurable per agent (agent.directories). Attempts to read/write outside whitelist are denied or gated for approval. Commands are matched against a safelist.

### WARRIOR Mode
**Use Case:** Production autonomous work, significant automation, trusted workflows

- **File access:** ✅ Free read/write to agent's workspace directories
- **External file access:** 🟡 Read allowed with approval; write denied (read-only external access)
- **Commands:** ✅ Can execute any command scoped to workspace directories
- **Python:** ✅ Can install packages (requires approval), run any code sandboxed
- **Web access:** ✅ Unrestricted
- **Delegation:** ✅ Can spawn other agents
- **Iteration limit:** 400 iterations (very high; prevents infinite loops only)
- **Approval gate:** Only installs and harness modifications require approval

**Implementation:** `/Sources/classes/modes/WarriorMode.swift`

Most actions allowed; approval gates only system-wide state changes (installs) or agent delegation. File I/O checked via `FileUtilities.inSessionDirectories(path:directories:)`.

### ULTIMATE Mode
**Use Case:** Unrestricted system access, long-running tasks, advanced automation

- **File access:** ✅ Any directory, any operation
- **Commands:** ✅ Any command, no restrictions
- **Python:** ✅ Install, execute, no sandboxing
- **Delegation:** ✅ Spawn agents, no approval
- **Iteration limit:** None (no loop limit)
- **Approval gate:** None (no gates)

**Implementation:** `/Sources/classes/modes/UltimateMode.swift`

Minimal checks; essentially unrestricted. Used only when user explicitly grants and monitors.

---

## Permission System Architecture

### Core Data Structures

**`ModeAction` enum** — Categories of capabilities:
```swift
enum ModeAction: String {
    case all        // Full system access
    case read       // File reading
    case write      // File writing
    case delegate   // Spawn/message agents
    case install    // Package installation
    case web        // Web access
    case harness    // Modify harness (e.g., promote tools)
}
```

**`PermissionRequest` struct** — Request to perform an action:
```swift
struct PermissionRequest {
    let action: ModeAction      // What: read, write, delegate, etc.
    let target: String?         // Where/what: file path, package name, agent UUID
    let reason: String?         // Why: description for logging/approval UI
}
```

**`PermissionDecision` enum** — Outcome of evaluation:
```swift
enum PermissionDecision {
    case allowed                // Grant immediately
    case denied(reason: String) // Block with explanation
    case requiresApproval(reason: String)  // Ask user first
}
```

**`PermissionEvaluation` struct** — Complete evaluation result:
```swift
struct PermissionEvaluation {
    let request: PermissionRequest
    let decision: PermissionDecision
}
```

### Permission Evaluation Flow

```
Tool execution requested in Agent.run()
    │
    ├─ 1. Extract PermissionRequest(s) from tool call
    │      Example: ReadFile("/tmp/secret.txt") → PermissionRequest(action: .read, target: "/tmp/secret.txt")
    │
    ├─ 2. Call mode.evaluateRequests(requests, agent)
    │      ├─ For each request, call mode-specific logic
    │      ├─ Return: [PermissionEvaluation]
    │      └─ Examples:
    │         - Egg: all denied
    │         - Warrior: allowed if in workspace, requires approval if external
    │         - Ultimate: all allowed
    │
    ├─ 3. Check decisions
    │      ├─ If ANY denied → log, emit error, skip tool
    │      ├─ If ANY approval required → suspend, await user response
    │      └─ If all allowed → proceed
    │
    ├─ 4. Call mode.guardRequests(requests, agent)
    │      ├─ Throw if any request forbidden
    │      └─ Allows per-mode final validation before execution
    │
    └─ 5. Execute tool if guard passes
         └─ Tool runs with full access (trust boundary)
```

### Evaluation Logic by Mode

#### EggMode.evaluateRequests()
```swift
static func evaluateRequests(_ requests: [PermissionRequest], agent: Agent) -> [PermissionEvaluation] {
    var evaluations: [PermissionEvaluation] = []
    for request in requests {
        // Every action denied with mode-appropriate message
        evaluations.append(PermissionEvaluation(
            request: request,
            decision: .denied(reason: "Permission denied: \(request.action.rawValue) is forbidden in Egg mode.")
        ))
    }
    return evaluations
}

static func guardRequests(_ requests: [PermissionRequest], agent: Agent) throws {
    for request in requests {
        throw ModePermissionError.forbidden
    }
}
```

#### WarriorMode.evaluateRequests()
```swift
static func evaluateRequests(_ requests: [PermissionRequest], agent: Agent) -> [PermissionEvaluation] {
    var evaluations: [PermissionEvaluation] = []
    for request in requests {
        switch request.action {
        case .all:
            // Always deny unrestricted access
            evaluations.append(PermissionEvaluation(
                request: request,
                decision: .denied(reason: "Full access not permitted in Warrior mode.")
            ))
            
        case .read, .write:
            // Check if within workspace directories
            if let path = request.target,
               FileUtilities.inSessionDirectories(path: path, directories: agent.effectiveDirectories) {
                // Within workspace: allowed
                evaluations.append(PermissionEvaluation(request: request, decision: .allowed))
            } else {
                // Outside workspace: requires approval
                evaluations.append(PermissionEvaluation(
                    request: request,
                    decision: .requiresApproval(reason: "File outside workspace requires approval: \(request.target ?? "unknown")")
                ))
            }
            
        case .install, .harness:
            // Always require approval (system-wide impact)
            evaluations.append(PermissionEvaluation(
                request: request,
                decision: .requiresApproval(reason: "This action requires your approval.")
            ))
            
        case .web, .delegate:
            // Always allowed in Warrior
            evaluations.append(PermissionEvaluation(request: request, decision: .allowed))
        }
    }
    return evaluations
}
```

#### UltimateMode.evaluateRequests()
```swift
static func evaluateRequests(_ requests: [PermissionRequest], agent: Agent) -> [PermissionEvaluation] {
    // All requests approved
    return requests.map { PermissionEvaluation(request: $0, decision: .allowed) }
}
```

## Runtime Permission Checks

### Before Tool Execution

In `Agent.run()`:

```swift
// 1. Agent gets tool call from LLM response
let toolCall: ToolCall = ...  // e.g., read_file("/tmp/data.txt")

// 2. Find tool
guard let tool = agent.tools.first(where: { $0.name == toolCall.name }) else {
    // Tool not found
    appendError("Tool not found: \(toolCall.name)")
    continue
}

// 3. Build permission requests
let permissionRequests = tool.permissionRequests(args: toolCall.args, agent: agent)
// Tool defines what permissions it needs given its arguments

// 4. Evaluate with mode
let evaluations = mode.evaluateRequests(permissionRequests, agent: agent)

// 5. Check results
for evaluation in evaluations {
    switch evaluation.decision {
    case .denied(let reason):
        // Block immediately
        appendError(reason)
        continue toolLoop  // Skip this tool
        
    case .requiresApproval(let reason):
        // Suspend execution, request user approval
        let response = await requestUserApproval(reason)
        if !response.approved {
            appendError("User denied: \(reason)")
            continue toolLoop
        }
        
    case .allowed:
        // Proceed
        break
    }
}

// 6. Final guard check
try mode.guardRequests(permissionRequests, agent: agent)
// Throws if mode implementation forbids (double-check)

// 7. Execute tool
let result = try await tool.execute(args: toolCall.args)
```

### User Input Request

When agent requires user approval:

```swift
// Emit UserInputRequest event
let request = UserInputRequest(
    prompt: "Allow installation of numpy? This requires approval in Warrior mode.",
    requestType: .permissionApproval,
    metadata: ["action": "install", "target": "numpy"]
)
onEvent(.userInputRequest(request))

// Agent suspends; awaits response
// Client shows approval dialog to user
// User clicks "Approve" or "Deny"
// Response sent back via WebSocket
// Agent resumes or continues without tool
```

## Workspace Directories

Each agent has a list of whitelisted directories for safe I/O:

```swift
let agent = Agent(
    uuid: "agent-1",
    userUUID: "user-alice",
    mode: .warrior,
    directories: [
        "/Users/alice/Projects/my-app",
        "/tmp/work-session",
        "/var/log"  // Read-only in Warrior
    ]
)
```

**Directory scope:**

- **Egg:** No file access; directories field ignored
- **Fledgling:** All I/O must be in `directories` (strict whitelist)
- **Warrior:** Write unrestricted to `directories`; read can be outside (with approval); commands scoped to `directories`
- **Ultimate:** `directories` field has no effect

**Path checking:**

```swift
// FileUtilities.inSessionDirectories
static func inSessionDirectories(path: String, directories: [String]) -> Bool {
    return directories.contains { directory in
        path.hasPrefix(directory + "/") || path == directory
    }
}
```

## Iteration Limits

Each mode has a max iteration count (prevents infinite loops):

| Mode | Limit | Rationale |
|------|-------|-----------|
| Egg | ∞ | Safe; only conversation + memory |
| Fledgling | 10 | Early-stage; prevent runaway |
| Warrior | 400 | Production workloads can be complex |
| Ultimate | ∞ | User explicitly allowed unrestricted |

When agent reaches limit:

```swift
if iterationCount >= mode.iterationLimit ?? Int.max {
    // Stop gracefully
    appendMessage(role: .assistant, text: "Iteration limit reached. Please continue in a new message if needed.")
    break
}
```

## Extending Security

### Adding a New Mode

1. Create new file `/Sources/classes/modes/CustomMode.swift`:
```swift
class CustomMode: Mode {
    static let iterationLimit: Int? = 50
    
    static func evaluateRequests(_ requests: [PermissionRequest], agent: Agent) -> [PermissionEvaluation] {
        // Custom logic
    }
    
    static func guardRequests(_ requests: [PermissionRequest], agent: Agent) throws {
        // Pre-execution guard
    }
    
    static func getPermissionDescription(for action: ModeAction) -> String {
        // Human-readable descriptions
    }
}
```

2. Add to `ModeType` enum:
```swift
enum ModeType: String, Codable, CaseIterable {
    case custom = "CUSTOM"
    
    var modeClass: Mode.Type {
        switch self {
        case .custom: CustomMode.self
        // ...
        }
    }
}
```

3. Test with agents using the new mode.

### Custom Permission Evaluation

Modes can implement context-aware logic. For example:

```swift
// Schedule-based permissions (e.g., only allow automation during work hours)
if request.action == .all {
    let hour = Calendar.current.component(.hour, from: Date())
    if hour >= 9 && hour < 17 {
        return PermissionEvaluation(request: request, decision: .allowed)
    } else {
        return PermissionEvaluation(request: request, decision: .denied(reason: "Full access only during work hours."))
    }
}

// User-specific permissions (e.g., certain users never get Ultimate)
if agent.userUUID == "restricted-user" && request.action == .all {
    return PermissionEvaluation(request: request, decision: .denied(reason: "Your account doesn't have permission for this action."))
}
```

## Audit & Logging

Approved and denied permissions are logged for security audit:

- **Log location:** Console during development; could be persisted to `/databank/audit.log`
- **Content:**
  - Agent UUID, mode, requested action
  - Target (file path, command, package name)
  - Decision (allowed, denied, approval required)
  - Timestamp, user UUID

Example log entry:
```
[2026-06-15 14:23:45] Agent 'agent-abc' (user: alice) requested .write to '/Users/alice/Projects/app/file.swift'
Mode: WARRIOR | Decision: ALLOWED | Reason: Within workspace directories
```

## Best Practices

1. **Start conservative:** Use Egg or Fledgling; escalate only when needed
2. **Explicit workspaces:** Clearly define `directories` per agent
3. **Monitor approvals:** Log all approval-gated requests; review patterns
4. **Test mode transitions:** Verify behavior when mode changes mid-chat
5. **Document custom modes:** Explain decision logic in code comments
6. **User education:** Explain what each mode allows via UI help text

## Next Steps

- **[Agent Lifecycle](/openwiki/workflows/agent-lifecycle.md)** — See how permissions are evaluated during execution
- **[Tools & Skills](/openwiki/tools-and-skills/overview.md)** — Understand how tools define permission needs
- **[Data & Storage](/openwiki/data-and-storage/persistence.md)** — Audit logs and config persistence

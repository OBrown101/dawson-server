---
type: Architecture
title: Tools & Skills System
description: How DAWSON agents access capabilities through tools and reusable skill manifests, including the Tool protocol, skill framework, and extension patterns.
resource: /Sources/tools/
tags: [tools, skills, extensibility, capabilities]
---

# Tools & Skills System

DAWSON provides two complementary mechanisms for giving agents capabilities: **tools** for direct execution and **skills** for reusable knowledge and expertise.

## Tools

### Overview

A **tool** is an executable capability that agents can invoke during their reasoning loop. Tools are the bridge between an agent's reasoning and external action (file I/O, command execution, Python scripting, memory access, web requests, etc.).

### Tool Protocol

All tools implement the `Tool` protocol:

```swift
protocol Tool {
    // Human-readable name ("read_file", "run_command")
    var name: String { get }
    
    // One-line description for LLM
    var description: String { get }
    
    // JSON schema of input arguments
    var inputSchema: ToolInputSchema { get }
    
    // What permissions this tool needs (mode-dependent)
    func permissionRequests(args: [String: Any], agent: Agent) -> [PermissionRequest]
    
    // Execute the tool with given arguments
    func execute(args: [String: Any]) async throws -> ToolResult
}

struct ToolInputSchema {
    let properties: [String: JSONSchema]  // e.g., { "path": { type: "string" } }
    let required: [String]                // Required property names
}

struct ToolResult {
    let success: Bool
    let output: String  // Result text
    let metadata: [String: AnyCodable]?   // Optional structured data
}
```

### Required vs Optional Tools

#### Required Tools
Always available to every agent:

| Tool | Purpose |
|------|---------|
| `RequestUserInput` | Pause execution, ask user for input, resume with response |
| `EnvAwareness` | Get environment info (OS, Python version, current directory) |
| `GetFullSkill` | Load a skill manifest by name for deep expertise |
| `GetSessionInfo` | Get chat/agent/user metadata |
| **MemPalace tools (15+)** | Diary read/write, knowledge graph queries, memory search |

```swift
private static var requiredTools: [Tool] {
    [
        RequestUserInput(),
        EnvAwareness(),
        GetFullSkill(),
        GetSessionInfo()
    ] + Agent.memoryTools
}
```

#### Optional Tools
Available based on agent config; loaded on-demand:

| Category | Tools | Purpose |
|----------|-------|---------|
| **File I/O** | ReadFile, WriteFile, ReplaceInFile, Grep, Find, Tree | File reading, writing, searching, directory listing |
| **Command Execution** | RunCommand | Execute shell commands (mode-gated) |
| **Python** | RunPythonCode, RunPythonScript, InstallPythonPackage, ListPythonTools, PromotePythonTool | Python scripting, package management, tool promotion |
| **Web** | FetchURL | HTTP requests |
| **Media** | ReadImage | Load and analyze images (with vision models) |
| **Utility** | Speak, RichFormatter | Text-to-speech, formatted output |
| **MCP** | MCPTool | Invoke external Model Context Protocol tools |

```swift
private var optionalTools: [Tool] {
    [
        Grep(), Tree(), ReadImage(), FindFile(), ReadFile(), ReadPDF(),
        WriteFile(), ReplaceInFile(),
        Speak(), RichFormatter(),
        InstallPythonPackage(), ListPythonTools(),
        PromotePythonTool(workspace: { self.directories }),
        RunPythonScript(workspace: { self.directories }),
        RunPythonCode(workspace: { self.directories }),
        RunCommand(workspace: { self.directories }, mode: { self.mode })
    ]
}
```

### Tool Lifecycle

1. **Registration** — Agent creates list of available tools during initialization
2. **LLM Context** — Tool definitions (name, description, input schema) sent to LLM
3. **Selection** — LLM reasons about which tool to call for a task
4. **Permission Check** — Agent evaluates mode-specific permissions before execution
5. **Execution** — Tool runs; agent captures result
6. **History Update** — Tool call + result appended to message history
7. **Loop** — Agent may call more tools or conclude

### Implementing a New Tool

Example: A tool to query a database.

```swift
// File: /Sources/tools/QueryDatabase.swift

import Foundation

class QueryDatabase: Tool, Sendable {
    let name = "query_database"
    let description = "Execute a SQL query against the local database"
    
    let inputSchema = ToolInputSchema(
        properties: [
            "query": JSONSchema(type: "string", description: "SQL SELECT query"),
            "database": JSONSchema(type: "string", description: "Database file path")
        ],
        required: ["query", "database"]
    )
    
    func permissionRequests(args: [String: Any], agent: Agent) -> [PermissionRequest] {
        // Querying a database might be a read operation
        if let dbPath = args["database"] as? String {
            return [
                PermissionRequest(
                    action: .read,
                    target: dbPath,
                    reason: "Querying database: \(dbPath)"
                )
            ]
        }
        return []
    }
    
    func execute(args: [String: Any]) async throws -> ToolResult {
        guard let query = args["query"] as? String,
              let dbPath = args["database"] as? String else {
            throw ToolError.missingArguments
        }
        
        // Execute query
        let result = try executeQuery(query, at: dbPath)
        
        return ToolResult(
            success: true,
            output: result,
            metadata: ["rowCount": AnyCodable(result.split(separator: "\n").count)]
        )
    }
    
    private func executeQuery(_ query: String, at path: String) throws -> String {
        // Implementation: connect to database, run query, return results
        return "Query result..."
    }
}
```

Add to agent's optional tools:

```swift
private var optionalTools: [Tool] {
    [
        // ... existing tools ...
        QueryDatabase()
    ]
}
```

### Tool Patterns

#### Context-Aware Tools
Tools that capture agent context (workspace, mode):

```swift
class RunPythonCode: Tool {
    let workspace: () -> [String]  // Closure to get current workspace
    let mode: () -> ModeType       // Closure to get current mode
    
    init(workspace: @escaping () -> [String], mode: @escaping () -> ModeType) {
        self.workspace = workspace
        self.mode = mode
    }
    
    func execute(args: [String: Any]) async throws -> ToolResult {
        let currentWorkspace = workspace()
        let currentMode = mode()
        // ... use context during execution ...
    }
}
```

#### Tools with Side Effects
Tools that modify state (file writes, package installs) emit permission requests:

```swift
func permissionRequests(args: [String: Any], agent: Agent) -> [PermissionRequest] {
    if let filePath = args["filePath"] as? String {
        return [
            PermissionRequest(action: .write, target: filePath, reason: "Writing to \(filePath)")
        ]
    }
    return []
}
```

#### Tools with Validation
Tools that validate inputs before execution:

```swift
func execute(args: [String: Any]) async throws -> ToolResult {
    guard let input = args["input"] as? String else {
        throw ToolError.invalidInput("'input' parameter required")
    }
    
    // Validate format
    guard isValidFormat(input) else {
        return ToolResult(success: false, output: "Invalid input format")
    }
    
    // Proceed
    return ToolResult(success: true, output: processInput(input))
}
```

## Skills

### Overview

A **skill** is a reusable bundle of expertise and knowledge that an agent can access during reasoning. Unlike tools (which are executable), skills are informational—they contain context, patterns, best practices, and examples.

When an agent needs deep expertise on a topic, it calls the `GetFullSkill` tool to load the relevant skill manifest.

### Skill Manifest Format

Skills live in `/databank/skills/<skillname>/` with a `SKILL.md` file:

```markdown
---
name: migrate-wiki-to-okf
author: Ethan Brown
version: 1.0
tags: [wiki, okf, documentation]
description: Instructions for migrating an existing wiki to OKF format
---

# Migrate Wiki to OKF

Complete instructions for migrating an existing wiki to OKF format...

[Detailed steps, examples, patterns, etc.]
```

### Skill Metadata

The `SkillHandler` parses YAML frontmatter:

```swift
struct SkillMetadata {
    let name: String
    let author: String
    let version: String
    let tags: [String]
    let description: String
    let directory: String  // Full path to skill directory
}
```

### Discovering Skills

At startup, `SkillHandler.loadSkills()` scans `/databank/skills/`:

```swift
// SkillHandler.loadSkills()
func loadSkills() -> [SkillMetadata] {
    let skillsRoot = DAWSON.databank.appendingPathComponent("skills")
    
    var skills: [SkillMetadata] = []
    
    for directoryURL in contentsOfDirectory(skillsRoot) {
        // Look for SKILL.md
        let skillFile = directoryURL.appendingPathComponent("SKILL.md")
        
        if fileManager.fileExists(atPath: skillFile.path) {
            // Parse metadata
            let metadata = parseMetadata(content: readFile(skillFile))
            skills.append(metadata)
        }
    }
    
    return skills.sorted { $0.name < $1.name }
}
```

### Using Skills

When an agent needs expertise, it calls `GetFullSkill`:

```
Agent reasoning:
"I need to migrate a wiki to OKF format. Let me load the skill."

GetFullSkill(skillName: "migrate-wiki-to-okf")
    ↓
SkillHandler finds /databank/skills/migrate-wiki-to-okf/SKILL.md
    ↓
Full content of SKILL.md returned to agent
    ↓
Agent reads patterns, examples, steps
    ↓
Agent executes task with expertise
```

### Creating a Skill

1. Create directory:
```bash
mkdir -p /databank/skills/my-skill
```

2. Create `SKILL.md` with frontmatter:
```markdown
---
name: my-skill
author: Your Name
version: 1.0
tags: [tag1, tag2]
description: One-line summary
---

# Detailed Skill Content

Comprehensive instructions, patterns, examples...
```

3. Skills are automatically discovered on next DAWSON restart.

### Skill Examples in Repository

**`/skills/migrate-wiki-to-okf/`** — Instructions for OKF migration
- Explains OKF schema, front matter format, field requirements
- Step-by-step workflow
- Examples of compliant vs non-compliant files

**`/skills/write-connector/`** — Instructions for building OpenWiki connectors
- Connector architecture and interfaces
- Step-by-step implementation guide
- Patterns and best practices

## Tool vs Skill Comparison

| Aspect | Tool | Skill |
|--------|------|-------|
| **Execution** | Directly executed by agent | Informational; read by agent |
| **Input/Output** | Structured args → result | None (read-only) |
| **State Change** | May modify system (files, env) | No side effects |
| **Discovery** | Hard-coded per agent | Scanned from `/databank/skills/` |
| **Use Case** | Implement an action | Provide expertise/knowledge |
| **Example** | ReadFile, RunCommand | migrate-wiki-to-okf, write-connector |

## Permission-Aware Tools

Some tools are permission-sensitive; their execution depends on mode:

### RunCommand Example
```swift
class RunCommand: Tool {
    // ...
    func permissionRequests(args: [String: Any], agent: Agent) -> [PermissionRequest] {
        if let command = args["command"] as? String {
            return [
                PermissionRequest(
                    action: .all,  // Requires full permission
                    target: command,
                    reason: "Executing: \(command)"
                )
            ]
        }
        return []
    }
}
```

Execution flow:
1. Agent calls RunCommand with shell command
2. Agent evaluates permissions based on mode
3. If Egg mode → denied; agent informed
4. If Warrior mode → allowed (scoped to workspace); executes
5. If Ultimate mode → allowed; executes

## Tool Composition & Chaining

Agents often chain tool calls to accomplish complex tasks:

```
Goal: Analyze GitHub repository issues

1. FetchURL("https://api.github.com/repos/owner/repo/issues")
   → Returns: JSON list of issues

2. WriteFile("/tmp/issues.json", jsonData)
   → Writes data to disk for processing

3. RunPythonCode("""
   import json
   with open('/tmp/issues.json') as f:
       issues = json.load(f)
   # Process, filter, analyze
   """)
   → Performs computation

4. WriteFile("/tmp/analysis.md", markdown)
   → Writes summary report

5. Speak("Analysis complete")
   → Notifies user
```

## Best Practices for Tool Developers

1. **Clear Names & Descriptions** — Agent relies on these to decide when to use your tool
2. **Minimal Input Schema** — Only required parameters; make optional fields schema properties
3. **Comprehensive Permission Requests** — Declare all permissions your tool needs
4. **Graceful Error Handling** — Return ToolResult with success=false rather than throwing (unless exceptional)
5. **Limit Scope** — Single responsibility; don't combine multiple operations in one tool
6. **Documentation** — Include examples in description for LLM context

## Testing Tools

Agents test tools during execution. Manual testing:

```swift
// Create test tool
let tool = ReadFile()

// Test with valid arguments
let result = try await tool.execute(args: ["path": "/path/to/file.txt", "maxLines": 100])
XCTAssertTrue(result.success)
XCTAssertTrue(result.output.contains("expected content"))

// Test permission requests
let perms = tool.permissionRequests(args: ["path": "/sensitive/file.txt"], agent: testAgent)
XCTAssertEqual(perms[0].action, .read)
XCTAssertEqual(perms[0].target, "/sensitive/file.txt")
```

## Next Steps

- **[Security & Modes](/openwiki/security/modes-and-permissions.md)** — How permissions are evaluated during tool execution
- **[Agent Lifecycle](/openwiki/workflows/agent-lifecycle.md)** — How tools fit into the execution loop
- **[Integrations](/openwiki/integrations/)** — Python sandboxing, MCP tool integration

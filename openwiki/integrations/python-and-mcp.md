---
type: Integration
title: Python & MCP Integration
description: Python environment setup, PythonKit integration, sandboxing for agent code execution, and Model Context Protocol tool bridging.
resource: /Sources/classes/python/
tags: [integration, python, mcp, sandboxing]
---

# Python & MCP Integration

DAWSON integrates Python for scripting and computation, and Model Context Protocol (MCP) for external tool access. This document explains both subsystems.

## Python Integration

### Environment Setup

**Location:** `/Sources/classes/python/PythonEnv.swift`

Python 3.11 bundled with DAWSON:

```
/python-macos/
├── bin/
│   └── python3              # Python executable
├── lib/
│   ├── libpython3.11.dylib  # Python runtime
│   └── python3.11/
│       └── site-packages/   # Installed packages
```

**Initialization:**

```swift
class PythonEnv {
    static let pythonVersion = "3.11"
    static let pythonHome = DAWSON.root.appendingPathComponent("python-macos")
    static let pythonLibPath = pythonHome
        .appendingPathComponent("lib")
        .appendingPathComponent("libpython3.11.dylib")
        .path
    static let pythonPackagesPath = pythonHome
        .appendingPathComponent("lib/python3.11/site-packages")
        .path
    
    static func setEnv() {
        // MUST be called before PythonKit import
        setenv("PYTHONHOME", pythonHome.path, 1)
        setenv("PYTHONPATH", pythonPackagesPath, 1)
    }
}
```

### PythonKit Integration

**Location:** `/Sources/classes/python/PythonHandler.swift`

Direct Python execution via PythonKit:

```swift
class PythonHandler: @unchecked Sendable {
    static let shared = PythonHandler()
    
    func call(moduleName: String, functionName: String, args: [String: Any] = [:]) throws -> PythonObject {
        // Import module
        let module = try Python.attemptImport(moduleName)
        
        // Call function
        let pythonArgs = try PythonUtilities.toPython(args)
        let result = try module[functionName].dynamicallyCall(withArguments: pythonArgs)
        
        return result
    }
}
```

**Example: Call Python Function from Swift**

```swift
// Python code in /python-scripts/analyzer.py:
// def analyze_code(code: str) -> dict:
//     return {"lines": len(code.split("\n")), "chars": len(code)}

let result = try PythonHandler.shared.call(
    moduleName: "analyzer",
    functionName: "analyze_code",
    args: ["code": """
        func hello() {
            print("world")
        }
    """]
)

let linesCount = try Int(result["lines"])  // 3
let charsCount = try Int(result["chars"])   // ~33
```

### Sandboxed Execution

**Location:** `/Sources/classes/python/PythonSandbox.swift`

For untrusted code (agent-written scripts), use sandboxed subprocess:

```swift
class PythonSandbox {
    // Run Python code in isolated process
    static func execute(
        code: String,
        workingDirectory: String,
        timeout: TimeInterval = 30
    ) async throws -> SandboxedResult {
        let tempScript = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".py")
        
        try code.write(to: tempScript, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempScript) }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: PythonEnv.pythonExecPath)
        process.arguments = [tempScript.path]
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        
        // Set up pipes for stdout/stderr
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        
        // Wait with timeout
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        }
        
        if process.isRunning {
            process.terminate()
            throw SandboxError.timeout
        }
        
        let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        
        return SandboxedResult(
            exitCode: Int(process.terminationStatus),
            stdout: stdout,
            stderr: stderr,
            success: process.terminationStatus == 0
        )
    }
}
```

### Python Tools

Tools that execute Python code on behalf of agents:

#### RunPythonCode
Execute Python code inline:

```swift
class RunPythonCode: Tool {
    var name = "run_python_code"
    var description = "Execute Python code and return the result"
    
    func execute(args: [String: Any]) async throws -> ToolResult {
        guard let code = args["code"] as? String else {
            throw ToolError.missingArguments
        }
        
        let result = try await PythonSandbox.execute(
            code: code,
            workingDirectory: workspace()[0],
            timeout: 30
        )
        
        if result.success {
            return ToolResult(success: true, output: result.stdout)
        } else {
            return ToolResult(success: false, output: result.stderr)
        }
    }
    
    func permissionRequests(args: [String: Any], agent: Agent) -> [PermissionRequest] {
        // Check if code contains file operations
        if let code = args["code"] as? String, code.contains("open(") {
            return [PermissionRequest(action: .read, target: agent.directories[0], reason: "Python file I/O")]
        }
        return []
    }
}
```

Agent usage:
```
Agent: Let me analyze your data with Python.

RunPythonCode(code: """
import json
data = {"count": 42, "name": "example"}
print(json.dumps(data))
""")

Result: {"count": 42, "name": "example"}
```

#### RunPythonScript
Execute saved Python script:

```swift
class RunPythonScript: Tool {
    var name = "run_python_script"
    var description = "Execute a Python script from disk"
    
    func execute(args: [String: Any]) async throws -> ToolResult {
        guard let scriptPath = args["scriptPath"] as? String else {
            throw ToolError.missingArguments
        }
        
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            throw ToolError.fileNotFound(scriptPath)
        }
        
        let code = try String(contentsOfFile: scriptPath)
        let result = try await PythonSandbox.execute(
            code: code,
            workingDirectory: URL(fileURLWithPath: scriptPath).deletingLastPathComponent().path
        )
        
        return ToolResult(success: result.success, output: result.stdout + result.stderr)
    }
}
```

#### InstallPythonPackage
Install from PyPI:

```swift
class InstallPythonPackage: Tool {
    var name = "install_python_package"
    var description = "Install a Python package from PyPI"
    
    func execute(args: [String: Any]) async throws -> ToolResult {
        guard let packageName = args["packageName"] as? String else {
            throw ToolError.missingArguments
        }
        
        let result = try await PythonSandbox.execute(
            code: "import subprocess; subprocess.check_call(['pip', 'install', '\(packageName)'])",
            workingDirectory: FileManager.default.currentDirectoryPath,
            timeout: 300  // 5 min for install
        )
        
        return ToolResult(success: result.success, output: result.stdout)
    }
    
    func permissionRequests(args: [String: Any], agent: Agent) -> [PermissionRequest] {
        return [PermissionRequest(
            action: .install,
            target: args["packageName"] as? String ?? "unknown",
            reason: "Installing Python package requires approval"
        )]
    }
}
```

Installation requires approval in Warrior mode; always allowed in Ultimate.

## Model Context Protocol (MCP)

### Overview

MCP allows external tools to be exposed to agents. A local or remote service (e.g., GitHub API wrapper, database query tool) implements the MCP protocol; DAWSON's `MCPHandler` connects as a client.

### Architecture

```
Agent (wants to use external tool)
    ↓
MCPTool (internal wrapper)
    ↓
MCPHandler (client)
    ↓
MCPServer (transport)
    ↓
External Tool (e.g., GitHub API wrapper)
```

### MCPHandler

**Location:** `/Sources/classes/mcp/MCPHandler.swift`

```swift
class MCPHandler: @unchecked Sendable {
    static let shared = MCPHandler()
    
    private var servers: [String: MCPServer] = [:]
    
    // Register an MCP server
    func registerServer(
        serverName: String,
        transport: @escaping @Sendable () async throws -> Transport
    ) async throws {
        let transport = try await transport()
        let client = Client(name: "DAWSON", version: "1.0.0")
        
        try await client.connect(transport: transport)
        
        let server = MCPServer(name: serverName, client: client)
        servers[serverName] = server
    }
    
    // List available tools from a server
    func listTools(serverName: String) async throws -> [Tool] {
        guard let server = servers[serverName] else {
            throw MCPHandlerError.serverNotConnected(serverName)
        }
        
        return try await server.listTools()
    }
    
    // Call a tool
    func callTool(
        serverName: String,
        toolName: String,
        args: [String: Any]
    ) async throws -> String {
        guard let server = servers[serverName] else {
            throw MCPHandlerError.serverNotConnected(serverName)
        }
        
        return try await server.callTool(name: toolName, args: args)
    }
}
```

### MCPServer

**Location:** `/Sources/classes/mcp/MCPServer.swift`

```swift
class MCPServer {
    let name: String
    let client: Client
    
    func listTools() async throws -> [Tool] {
        let tools = try await client.listTools()
        return tools.map { tool in
            MCPTool(
                name: tool.name,
                description: tool.description ?? "",
                schema: tool.inputSchema,
                server: self
            )
        }
    }
    
    func callTool(name: String, args: [String: Any]) async throws -> String {
        let result = try await client.callTool(
            name: name,
            arguments: args as? [String: AnyCodable] ?? [:]
        )
        return result.description
    }
}
```

### MCPTool

Internal wrapper that agents can call:

```swift
class MCPTool: Tool {
    let name: String
    let description: String
    let inputSchema: ToolInputSchema
    let server: MCPServer
    
    func execute(args: [String: Any]) async throws -> ToolResult {
        let result = try await server.callTool(name: name, args: args)
        return ToolResult(success: true, output: result)
    }
    
    func permissionRequests(args: [String: Any], agent: Agent) -> [PermissionRequest] {
        // MCP tools may require permission (e.g., GitHub API access)
        return [
            PermissionRequest(
                action: .web,  // Assume web access needed
                target: name,
                reason: "MCP tool \(name) requires external access"
            )
        ]
    }
}
```

### Registering an MCP Server

Example: GitHub tool server

```swift
// During DAWSON initialization or on demand
try await MCPHandler.shared.registerServer(
    serverName: "github",
    transport: {
        // Transport can be stdio, HTTP, etc.
        // For GitHub wrapper running as subprocess:
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/mcp-github-tools")
        process.arguments = ["--api-key", githubToken]
        
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        
        try process.run()
        
        return StdioTransport(
            input: inputPipe.fileHandleForWriting,
            output: outputPipe.fileHandleForReading
        )
    }
)

// Tools are now available:
// - get_user_repos
// - create_issue
// - list_pull_requests
// etc.
```

Agent can now use:

```
Agent: Let me check your GitHub repositories.

MCPTool(serverName: "github", tool: "get_user_repos", args: { "username": "octocat" })

Result: [
  { "name": "Hello-World", "stars": 1000 },
  { "name": "octocat", "stars": 500 }
]
```

## Limitations & Future Work

### Python Sandboxing

Current implementation:
- Subprocess isolation (process-level sandbox)
- No resource limits (CPU, memory, disk)
- Timeout-based kill (30s default)

Future improvements:
- Resource limits via cgroups (Linux)
- Whitelist/blacklist module imports
- File system restrictions (chroot)

### MCP Support

Current:
- Single MCP server per transport
- Read-only tools only
- Basic error handling

Future:
- Multiple MCP servers
- Mutation tools (with approval)
- Bidirectional streaming (for long-running tools)
- MCP server discovery & auto-registration

## Next Steps

- **[Tools & Skills](/openwiki/tools-and-skills/overview.md)** — Tool ecosystem
- **[Security & Modes](/openwiki/security/modes-and-permissions.md)** — Python execution gating
- **[Agent Lifecycle](/openwiki/workflows/agent-lifecycle.md)** — Tool invocation during execution

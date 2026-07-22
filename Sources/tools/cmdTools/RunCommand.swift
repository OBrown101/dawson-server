//
//  RunCommand.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/21/26.
//

import Foundation

class RunCommand: PermissionAware {
    // Used run commands sandboxed (below-Ultimate mode, not-sandboxed in Ultimate)
    
    static let name = "run_command"

    private let workspace: () -> [String]
    private let mode: () -> ModeType
    private let userAllowedCmds: () -> Set<String>

    private var timeout: TimeInterval = 120

    init(
        workspace: @escaping () -> [String],
        mode: @escaping () -> ModeType,
        userAllowedCmds: @escaping () -> Set<String> = { [] }
    ) {
        self.workspace = workspace
        self.mode = mode
        self.userAllowedCmds = userAllowedCmds
    }

    func permissionRequests(args: [String: Any]) -> [PermissionRequest] {
        let command = (args["command"] as? String) ?? ""
        let mode = mode()

        if (mode == .ultimate) {
            // Ultimate: unsandboxed, unrestricted (user accepted full risk)
            return [PermissionRequest(action: .command)]
        }

        let classification = CommandClassifier.classify(command, userAllowed: userAllowedCmds())
        switch classification {
        case .denied(let reason):
            return [PermissionRequest(action: .command, target: "DENIED: \(reason)")]
        case .prompt:
            // Force approval regardless of mode's default for .command
            return [PermissionRequest(action: .command,
                                      requirement: .userApproval,
                                      reason: "Run unrecognized command (sandboxed to your workspace): \(command)")]
        case .safe:
            // Normal mode decision
            return [PermissionRequest(action: .command, target: workspace().first)]
        }
    }

    private let toolDescription = """
        Runs a terminal command. Below Ultimate mode the command is confined to \
        this chat's workspace directories by an OS-level sandbox and has no \
        network access — it cannot read, write, or affect anything outside your \
        workspace. Common inspect/build/test commands run directly; unrecognized \
        commands require one approval, then run sandboxed; privilege-escalation, \
        destructive, and network commands are refused (use fetch_url for the \
        web, \(InstallPythonPackage.name) for packages). Prefer the dedicated file \
        tools for reading/editing; use this for builds, tests, git, and CLI \
        tools.
        """

    private let parameterSchema: [String: Any] = [
        "type": "object",
        "required": ["command"],
        "properties": [
            "command": [
                "type": "string",
                "description": "The command line to run (e.g. 'swift build', 'git status', 'npm test')"
            ],
            "working_directory": [
                "type": "string",
                "description": "Directory to run in; must be within the workspace. Defaults to the first workspace directory."
            ]
        ]
    ]

    func openAISchema() -> [String: Any] {
        return [
            "type": "function",
            "name": RunCommand.name,
            "description": toolDescription,
            "parameters": parameterSchema
        ]
    }
    func anthropicSchema() -> [String: Any] {
        return [
            "name": RunCommand.name,
            "description": toolDescription,
            "input_schema": parameterSchema
        ]
    }
    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": RunCommand.name,
                "description": toolDescription,
                "parameters": parameterSchema
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let command = (args["command"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !command.isEmpty else {
            return "Error: Missing required parameter 'command'."
        }

        let workspaces = workspace()
        guard let primary = workspaces.first else {
            return "Error: No workspace configured for this chat; command execution is disabled."
        }
        let mode = mode()

        // Working directory must be inside the workspace.
        let workingDir = (args["working_directory"] as? String) ?? primary
        let canonicalWD = URL(fileURLWithPath: workingDir).resolvingSymlinksInPath().path
        let inWorkspace = workspaces.contains { root in
            let r = URL(fileURLWithPath: root).resolvingSymlinksInPath().path
            let rr = r.hasSuffix("/") ? r : r + "/"
            return (canonicalWD == r) || (canonicalWD + "/").hasPrefix(rr)
        }
        guard inWorkspace else {
            return "Error: working_directory '\(workingDir)' is outside your workspace."
        }

        // Re-check classification at execute time (defense in depth; the
        // permission layer already gated it, but never trust a single gate).
        if (mode != .ultimate) {
            switch CommandClassifier.classify(command, userAllowed: userAllowedCmds()) {
            case .denied(let reason):
                return "Command refused (\(reason)). This is not permitted below Ultimate mode. If it involves packages use install_python_package; if the web, use fetch_url."
            case .safe, .prompt:
                break
            }
        }

        do {
            let result: HostProcessResult
            if (mode == .ultimate) {
                // Unsandboxed host execution.
                let timeout = self.timeout
                result = try await Task.detached(priority: .userInitiated) {
                    try HostProcess.run(
                        executable: "/bin/sh",
                        arguments: ["-c", command],
                        currentDirectory: URL(fileURLWithPath: canonicalWD),
                        timeout: timeout
                    )
                }.value
            } else {
                // Sandboxed: /bin/sh -c "command" wrapped by the OS sandbox,
                // workspace writable, network denied.
                var spec = SandboxSpec(writableDirectories: workspaces)
                spec.allowNetwork = false
                spec.timeout = timeout

                let sandboxResult = try await Task.detached(priority: .userInitiated) {
                    try PythonHandler.shared.runSandboxedCommand(
                        shellCommand: command,
                        workingDirectory: canonicalWD,
                        spec: spec
                    )
                }.value
                result = HostProcessResult(
                    exitCode: sandboxResult.exitCode,
                    stdout: sandboxResult.stdout,
                    stderr: sandboxResult.stderr,
                    timedOut: sandboxResult.timedOut
                )
            }

            if (result.timedOut) {
                return "Command timed out after \(Int(timeout))s and was killed."
            }

            let out = truncate(result.stdout, limit: 10_000)
            let err = truncate(result.stderr, limit: 4_000)
            let sandboxNote = (mode == .ultimate) ? "" : " (ran sandboxed in workspace)"

            if (result.exitCode == 0) {
                return out.isEmpty
                    ? "Command completed successfully with no output\(sandboxNote)."
                    : "Command output\(sandboxNote):\n\(out)"
            }
            return """
            Command exited with code \(result.exitCode)\(sandboxNote).
            stdout: \(out.isEmpty ? "(empty)" : out)
            stderr: \(err.isEmpty ? "(empty)" : err)
            """
        } catch {
            return "Command execution error: \(error)"
        }
    }

    private func truncate(_ s: String, limit: Int) -> String {
        guard (s.count > limit) else { return s }
        return String(s.prefix(limit)) + "\n…[output truncated: \(s.count - limit) more characters]"
    }
}

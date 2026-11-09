//
//  RunCommand.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/21/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

class RunCommand: PermissionAware {
    // Used run commands sandboxed (below-Ultimate mode, not-sandboxed in Ultimate)
    
    static let name = "run_command"

    private let workspace: () -> [String]
    private let mode: () -> ModeType
    private let userAllowedCmds: () -> Set<String>
    
    // TODO: CONNECT TO PER-CHAT SWITCH (UI + AGENT METADATA) SO LOOPBACK BE USER ENABLED/DISABLED.
    // DEFAULT ON UNTIL THEN. NEVER HONORED BELOW WARRIOR — SEE loopbackPermitted(for:).
    private let loopbackEnabled: () -> Bool

    var defaultTimeout: TimeInterval = 120
    var maxTimeout: TimeInterval = 800  // Cold Gradle/Xcode builds routinely exceed several minutes

    init(
        workspace: @escaping () -> [String],
        mode: @escaping () -> ModeType,
        userAllowedCmds: @escaping () -> Set<String> = { [] },
        loopbackEnabled: @escaping () -> Bool = { true }
    ) {
        self.workspace = workspace
        self.mode = mode
        self.userAllowedCmds = userAllowedCmds
        self.loopbackEnabled = loopbackEnabled
    }

    private func loopbackPermitted(for mode: ModeType) -> Bool {
        // Loopback reaches host services (macOS has no network namespaces), so
        // Warrior-and-above capability only (switch or not).
        guard (mode.rank >= ModeType.warrior.rank) else { return false }
        return loopbackEnabled()
    }

    func permissionRequests(args: [String: Any]) -> [PermissionRequest] {
        let command = (args["command"] as? String) ?? ""
        let currentMode = mode()

        // Ultimate: unsandboxed, unrestricted (user accepted full risk)
        if (currentMode == .ultimate) {
            return [PermissionRequest(action: .all)]
        }

        // Resolve the intended working directory for the permission target,
        // so the mode's in-workspace check evaluates the real location.
        let target = (args["working_directory"] as? String) ?? workspace().first

        switch CommandClassifier.classify(command, userAllowed: userAllowedCmds()) {
        case .denied(let reason):
            // Hard refusal: express as an already-denied write so no mode can pass it.
            // Tool also re-checks at execute time (defense in depth).
            return [PermissionRequest(
                action: .write,
                target: target,
                requirement: .deny,
                reason: "Command refused (\(reason)); not permitted below Ultimate mode."
            )]

        case .prompt:
            // Unrecognized: force one approval regardless of the mode's default,
            // then it runs sandboxed. Treated as a write (can't prove it observes).
            return [PermissionRequest(
                action: .write,
                target: target,
                requirement: .userApproval,
                reason: "Run unrecognized command (sandboxed to your workspace): \(command)"
            )]

        case .read:
            return [PermissionRequest(action: .read, target: target)]

        case .write:
            return [PermissionRequest(action: .write, target: target)]
        }
    }

    private let toolDescription = """
        Runs a terminal command. Below Ultimate mode the command is confined to \
        this chat's workspace directories by an OS-level sandbox and has no \
        network access — it cannot read, write, or affect anything outside your \
        workspace. Common inspect/build/test commands run directly; unrecognized \
        commands require one approval, then run sandboxed; privilege-escalation, \
        destructive, and network commands are refused (use \(FetchURL.name) for the \
        web, \(InstallPythonPackage.name) for packages). Prefer the dedicated file \
        tools for reading/editing; use this for builds, tests, git, and CLI \
        tools.
        """

    private var parameterSchema: [String: Any] { [
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
            ],
            "timeout_seconds": [
                "type": "integer",
                "description": "Optional wall-clock limit in seconds (default \(Int(defaultTimeout)), max \(Int(maxTimeout))). Builds often need more; the process is killed when exceeded."
            ]
        ]
    ] }

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
        
        // JSON numbers may decode as Int or Double depending on the provider.
        let requestedTimeout: TimeInterval
        if let t = args["timeout_seconds"] as? Double {
            requestedTimeout = t
        } else if let t = args["timeout_seconds"] as? Int {
            requestedTimeout = TimeInterval(t)
        } else {
            requestedTimeout = defaultTimeout
        }
        let timeout = min(max(requestedTimeout, 1), maxTimeout)

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
                return "Command refused (\(reason)). This is not permitted below Ultimate mode. If it involves packages use \(InstallPythonPackage.name); if the web, use \(FetchURL.name)."
            case .read, .write, .prompt:
                break
            }
        }

        do {
            let result: HostProcessResult
            if (mode == .ultimate) {
                // Unsandboxed host execution.
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
                spec.allowLoopback = loopbackPermitted(for: mode)
                spec.executableDirectories = DeveloperTools.hostToolchainPaths
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
                // Surface partial output so a hang is distinguishable from slowness.
                let out = truncate(result.stdout, limit: 6_000)
                let err = truncate(result.stderr, limit: 4_000)
                return """
                Command timed out after \(Int(timeout))s and was killed. If the work \
                legitimately needs longer, retry with a higher timeout_seconds (max \(Int(maxTimeout))).
                stdout before kill: \(out.isEmpty ? "(empty)" : out)
                stderr before kill: \(err.isEmpty ? "(empty)" : err)
                """
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

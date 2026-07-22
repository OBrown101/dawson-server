//
//  RunPythonScript.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/21/26.
//

import Foundation

class RunPythonScript: PermissionAware {
    static let name = "run_python_script"
    
    private let workspace: () -> [String]
    
    var defaultTimeout: TimeInterval = 60
    var maxTimeout: TimeInterval = 600  // Potentially scale based on permission mode (e.g. 120 at Egg, 900 at Ultimate)
    var allowNetwork: Bool = false  // TODO: Wire up to permission modes
    
    init(workspace: @escaping () -> [String]) {
        self.workspace = workspace
    }
    
    func permissionRequests(args: [String: Any]) -> [PermissionRequest] {
        return [PermissionRequest(action: .write, target: workspace().first)]
    }
    
    private var toolDescription: String {
        """
        Executes a Python function from a specified module and returns the result. \
        The function is called with KEYWORD ARGUMENTS ONLY — fn(**args) — so the target \
        function's parameters must match the keys in 'args', and all values must be \
        JSON-serializable. Runs in DAWSON's bundled Python inside an OS-level sandbox: \
        file access is limited to this chat's workspace directories, there is no \
        network access, and every call is a fresh interpreter process (no state \
        persists between calls — persist state to workspace files instead). Modules \
        are importable from the workspace directories and from DAWSON's shared \
        python-scripts library (call list_python_tools FIRST to see what library \
        tools already exist before writing new code). For quick throwaway \
        snippets, use run_python_code instead. Missing third-party packages can \
        be requested with install_python_package; reusable tools can be saved to \
        the shared library with promote_python_tool.
        """
    }
    
    private var parameterSchema: [String: Any] {
        [
            "type": "object",
            "required": ["module", "function"],
            "properties": [
                "module": [
                    "type": "string",
                    "description": "The Python module name to import (e.g. 'mymodule', or 'pkg.mymodule' for workspace subdirectories)"
                ],
                "function": [
                    "type": "string",
                    "description": "The function name inside the module to execute"
                ],
                "args": [
                    "type": "object",
                    "description": "Dictionary of keyword arguments passed to the function as fn(**args). Values must be JSON-serializable. Pass large data via workspace files, not through this dictionary.",
                    "additionalProperties": true
                ],
                "timeout_seconds": [
                    "type": "integer",
                    "description": "Optional wall-clock limit in seconds (default \(Int(defaultTimeout)), max \(Int(maxTimeout))). The process is killed when exceeded, so request more time for long-running work."
                ]
            ]
        ]
    }
    
    func openAISchema() -> [String: Any] {
        return [
            "type": "function",
            "name": RunPythonScript.name,
            "description": toolDescription,
            "parameters": parameterSchema
        ]
    }

    func anthropicSchema() -> [String: Any] {
        return [
            "name": RunPythonScript.name,
            "description": toolDescription,
            "input_schema": parameterSchema
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": RunPythonScript.name,
                "description": toolDescription,
                "parameters": parameterSchema
            ]
        ]
    }
    
    func execute(args: [String: Any]) async -> String {
        guard let module = args["module"] as? String,
              let function = args["function"] as? String else {
            return "Error: Missing required parameters 'module' or 'function'"
        }
        let rawArgs = args["args"] as? [String: Any] ?? [:]

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
        guard (!workspaces.isEmpty) else {
            // No workspace means no safe place to run.
            return "Error: No workspace directories are configured for this chat, so Python execution is disabled."
        }

        var spec = SandboxSpec(writableDirectories: workspaces)
        spec.readOnlyDirectories = [
            DAWSON.root.appendingPathComponent("python-scripts").path
        ]
        spec.allowNetwork = allowNetwork
        spec.timeout = timeout

        let payloadData: Data
        do {
            payloadData = try JSONSerialization.data(withJSONObject: [
                "module": module,
                "function": function,
                "args": rawArgs
            ])
        } catch {
            return "Python execution error: could not encode arguments: \(error)"
        }
        let sendableSpec = spec
        
        // runSandboxed blocks on the subprocess; hop off the cooperative pool.
        let result: SandboxedResult
        do {
            result = try await Task.detached(priority: .userInitiated) {
                try PythonHandler.shared.runSandboxed(
                    payload: payloadData,
                    spec: sendableSpec
                )
            }.value
        } catch {
            return "Python execution error: \(error)"
        }

        if (result.timedOut) {
            return "Python execution error: timed out after \(Int(timeout))s and was killed. If the work legitimately needs longer, retry with a higher timeout_seconds (max \(Int(maxTimeout)))."
        }

        // Bootstrap prints exactly one JSON object as the last stdout line.
        if let line = result.stdout
            .split(separator: "\n", omittingEmptySubsequences: true)
            .last,
           let data = line.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

            if obj["ok"] as? Bool == true {
                let value = obj["result"].map { String(describing: $0) } ?? "None"
                // Include anything the script itself printed before the result,
                // truncated so runaway prints don't flood the model's context.
                let printed = Self.truncate(
                    result.stdout
                        .split(separator: "\n", omittingEmptySubsequences: true)
                        .dropLast()
                        .joined(separator: "\n"),
                    limit: 8_000
                )
                return printed.isEmpty ? value : "\(printed)\n\nResult: \(value)"
            }

            let err = obj["error"] as? String ?? "unknown Python error"
            return "Python execution error:\n\(Self.truncate(err, limit: 8_000))"
        }

        // Process died before the bootstrap could report (e.g. sandbox kill, interpreter crash).
        // Surface everything we have.
        return """
        Python execution error: process exited with code \(result.exitCode) \
        without a result.
        stdout: \(result.stdout.isEmpty ? "(empty)" : Self.truncate(result.stdout, limit: 4_000))
        stderr: \(result.stderr.isEmpty ? "(empty)" : Self.truncate(result.stderr, limit: 4_000))
        """
    }

    private static func truncate(_ s: String, limit: Int) -> String {
        guard s.count > limit else { return s }
        return s.prefix(limit) + "\n… [output truncated: \(s.count - limit) more characters]"
    }
}

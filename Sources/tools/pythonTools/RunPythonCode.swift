//
//  RunPythonCode.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/21/26.
//

import Foundation

class RunPythonCode: PermissionAware {
    // Used for quick sandboxed Python snippets (without write/import-module)
    // Saves to `scratch/` workspace folder
    // Scratch snippets older than `scratchRetentionDays` are pruned automatically.
    
    static let name = "run_python_code"

    private let workspace: () -> [String]

    var defaultTimeout: TimeInterval = 60
    var maxTimeout: TimeInterval = 600
    var allowNetwork: Bool = false

    var scratchRetentionDays: Int = 7   // Scratch snippets older than this are deleted on each call

    static let scratchFolderName = ".dawson_scratch"

    init(workspace: @escaping () -> [String]) {
        self.workspace = workspace
    }

    func permissionRequests(args: [String: Any]) -> [PermissionRequest] {
        return [PermissionRequest(action: .write, target: workspace().first)]
    }

    private var toolDescription: String {
        """
        Executes a short Python snippet and returns its printed output. Use this \
        for quick, throwaway work — inspecting a file's structure, small \
        calculations, one-off transformations, checking whether a package is \
        installed. The code runs top-to-bottom as a script (use print() for \
        output) in the same sandbox as run_python_script: file access limited to \
        the workspace, no network, fresh process each call. The snippet is saved \
        into the workspace's '\(Self.scratchFolderName)/' folder, so a snippet \
        that proves useful can be developed into a proper module and promoted. \
        For reusable multi-function tools, write a module and use \
        \(RunPythonScript.name) instead.
        """
    }

    private var parameterSchema: [String: Any] {
        [
            "type": "object",
            "required": ["code"],
            "properties": [
                "code": [
                    "type": "string",
                    "description": "Python source to execute top-to-bottom. Use print() to emit results."
                ],
                "timeout_seconds": [
                    "type": "integer",
                    "description": "Optional wall-clock limit in seconds (default \(Int(defaultTimeout)), max \(Int(maxTimeout)))."
                ]
            ]
        ]
    }

    func openAISchema() -> [String: Any] {
        return [
            "type": "function",
            "name": RunPythonCode.name,
            "description": toolDescription,
            "parameters": parameterSchema
        ]
    }

    func anthropicSchema() -> [String: Any] {
        return [
            "name": RunPythonCode.name,
            "description": toolDescription,
            "input_schema": parameterSchema
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": RunPythonCode.name,
                "description": toolDescription,
                "parameters": parameterSchema
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let code = args["code"] as? String,
              (!code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) else {
            return "Error: Missing required parameter 'code'"
        }

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
        guard let primaryWorkspace = workspaces.first else {
            return "Error: No workspace directories are configured for this chat, so Python execution is disabled."
        }

        // Write the snippet into the scratch folder
        let scratchDir = URL(fileURLWithPath: primaryWorkspace).appendingPathComponent(Self.scratchFolderName)
        let scriptURL: URL
        do {
            try FileManager.default.createDirectory(at: scratchDir, withIntermediateDirectories: true)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let stamp = formatter.string(from: Date())
            let shortID = UUID().uuidString.prefix(8)
            scriptURL = scratchDir.appendingPathComponent("snippet_\(stamp)_\(shortID).py")
            try code.write(to: scriptURL, atomically: true, encoding: .utf8)
        } catch {
            return "Error: Could not write snippet into the workspace scratch folder: \(error)"
        }

        pruneScratch(scratchDir)

        // --- Execute through the same sandbox as run_python_script ---
        var spec = SandboxSpec(writableDirectories: workspaces)
        spec.readOnlyDirectories = [
            DAWSON.root.appendingPathComponent("python-scripts").path
        ]
        spec.allowNetwork = allowNetwork
        spec.timeout = timeout

        let result: SandboxedResult
        do {
            result = try await Task.detached(priority: .userInitiated) {
                try PythonHandler.shared.runSandboxedScript(
                    scriptPath: scriptURL.path,
                    spec: spec
                )
            }.value
        } catch {
            return "Python execution error: \(error)"
        }

        let relativePath = "\(Self.scratchFolderName)/\(scriptURL.lastPathComponent)"

        if (result.timedOut) {
            return "Python execution error: timed out after \(Int(timeout))s and was killed. (Snippet saved as \(relativePath).) If the work legitimately needs longer, retry with a higher timeout_seconds (max \(Int(maxTimeout)))."
        }

        let stdout = Self.truncate(result.stdout, limit: 8_000)
        if (result.exitCode == 0) {
            return (stdout.isEmpty)
                ? "Snippet ran successfully with no printed output. (Saved as \(relativePath).) Use print() to emit results."
                : stdout
        }

        return """
        Python snippet failed (exit \(result.exitCode), saved as \(relativePath)):
        \(Self.truncate((result.stderr.isEmpty) ? result.stdout : result.stderr, limit: 8_000))
        """
    }

    private func pruneScratch(_ scratchDir: URL) {
        // Deletes scratch snippets older than the retention window. Best-effort.
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: scratchDir,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-TimeInterval(scratchRetentionDays) * 86_400)
        for file in files where (file.pathExtension == "py") {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? Date()
            if (modified < cutoff) {
                try? fm.removeItem(at: file)
            }
        }
    }

    private static func truncate(_ s: String, limit: Int) -> String {
        guard (s.count > limit) else { return s }
        return s.prefix(limit) + "\n… [output truncated: \(s.count - limit) more characters]"
    }
}

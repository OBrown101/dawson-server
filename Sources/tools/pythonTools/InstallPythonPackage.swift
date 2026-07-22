//
//  InstallPythonPackage.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/21/26.
//

import Foundation

class InstallPythonPackage: PermissionAware {
    // Used to install 3rd-party package to DAWSON bundled interpreter
    
    //  Security notes — read before wiring in:
    //  - pip install RUNS CODE host-side (build hooks, setup.py) with
    //    server's privileges/full-network access. Must ALWAYS be permission-gated
    //    to allow user make final decision.
    //  - The package argument is validated against a strict PEP-508-ish
    //    pattern: names, extras, and version specifiers only. URLs, local
    //    paths, VCS refs (git+...), and anything starting with '-' (flag
    //    injection) are rejected.
    //  - Installed specs are appended to plain-text ledger:
    //      DAWSON.root/python-installed-packages.txt
    
    static let name = "install_python_package"

    var installTimeout: TimeInterval = 300  // pip can be slow on big packages with native wheels

    func permissionRequests(args: [String: Any]) -> [PermissionRequest] {
        return [
            PermissionRequest(action: .install)
        ]
    }

    private let toolDescription = """
        Installs a third-party Python package into DAWSON's bundled interpreter, \
        making it importable in ALL \(RunPythonScript.name) calls from then on (this and \
        future conversations, all agents). Requires explicit user approval and \
        network access on the host. Accepts a package name with optional extras \
        and version specifier (e.g. 'requests', 'pandas==2.2.2', \
        'httpx[http2]>=0.27'). URLs, file paths, and VCS references are not \
        allowed. By default only pre-built wheels are installed (no code runs at \
        install time); if a package has no wheel for this platform, retry with \
        allow_source_build: true, which requires building from source. Before \
        requesting an installation, first try the task with already-available \
        packages and the standard library.
        """

    private let parameterSchema: [String: Any] = [
        "type": "object",
        "required": ["package", "reason"],
        "properties": [
            "package": [
                "type": "string",
                "description": "Package requirement: name with optional [extras] and version specifier, e.g. 'beautifulsoup4' or 'numpy>=1.26,<2'. One package per call."
            ],
            "reason": [
                "type": "string",
                "description": "One sentence explaining why this package is needed, shown to the user in the approval prompt."
            ],
            "allow_source_build": [
                "type": "boolean",
                "description": "Permit building from source if no pre-built wheel exists (default false). Source builds execute the package's build scripts during installation — only request this when a wheels-only install has already failed."
            ]
        ]
    ]

    func openAISchema() -> [String: Any] {
        return [
            "type": "function",
            "name": InstallPythonPackage.name,
            "description": toolDescription,
            "parameters": parameterSchema
        ]
    }

    func anthropicSchema() -> [String: Any] {
        return [
            "name": InstallPythonPackage.name,
            "description": toolDescription,
            "input_schema": parameterSchema
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": InstallPythonPackage.name,
                "description": toolDescription,
                "parameters": parameterSchema
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let package = (args["package"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) else {
            return "Error: Missing required parameter 'package'"
        }
        guard (Self.isValidRequirement(package)) else {
            return """
            Error: '\(package)' is not an acceptable package specification. \
            Use a plain package name with optional [extras] and version specifier \
            (e.g. 'requests', 'pandas==2.2.2'). URLs, paths, VCS references, and \
            pip flags are not permitted.
            """
        }

        let allowSourceBuild = args["allow_source_build"] as? Bool ?? false

        // Wheels-only by default: installing a pre-built wheel executes no
        // package code at install time. Source builds (sdists) run arbitrary
        // build backends, so they're opt-in per call and visible in the
        // approval prompt via the args.
        var pipArgs = ["install", "--no-input", "--disable-pip-version-check", "--no-color"]
        if !allowSourceBuild {
            pipArgs += ["--only-binary", ":all:"]
        }
        pipArgs.append(package)

        let result: HostProcessResult
        do {
            result = try Self.runPip(arguments: pipArgs, timeout: self.installTimeout)
        } catch {
            return "Package installation error: \(error)"
        }

        if result.timedOut {
            return "Package installation error: pip timed out after \(Int(installTimeout))s and was killed. The package may be partially installed; retrying is safe."
        }

        guard result.exitCode == 0 else {
            let output = result.stderr.isEmpty ? result.stdout : result.stderr
            var hint = ""
            if !allowSourceBuild,
               output.contains("Could not find a version") || output.lowercased().contains("only binary") {
                hint = "\nNo pre-built wheel may exist for this platform. If the package is trustworthy, retry with allow_source_build: true."
            }
            return """
            Package installation failed (exit \(result.exitCode)):
            \(Self.tail(output, lines: 30))\(hint)
            """
        }

        Self.appendToLedger(allowSourceBuild ? "\(package)  (source build)" : package)

        return """
        Installed '\(package)' into DAWSON's Python environment. It is immediately \
        importable in \(RunPythonScript.name) calls (the runtime is mounted read-only \
        into the sandbox, so new packages are visible without any restart).
        \(Self.tail(result.stdout, lines: 5))
        """
    }
}

extension InstallPythonPackage {
    
    private nonisolated static func runPip(arguments: [String], timeout: TimeInterval) throws -> HostProcessResult {
        let env = pipEnvironment()

        // Embedded runtimes sometimes ship without pip; bootstrap it once.
        let probe = try HostProcess.run(
            executable: PythonEnv.pythonExecPath,
            arguments: ["-m", "pip", "--version"],
            environment: env,
            timeout: 30
        )
        if (!probe.succeeded) {
            let bootstrap = try HostProcess.run(
                executable: PythonEnv.pythonExecPath,
                arguments: ["-m", "ensurepip", "--upgrade"],
                environment: env,
                timeout: 120
            )
            if (!bootstrap.succeeded) {
                throw PythonError.processFailed(
                    "pip is not available in the bundled runtime and ensurepip failed: \(tail(bootstrap.stderr, lines: 10))"
                )
            }
        }

        return try HostProcess.run(
            executable: PythonEnv.pythonExecPath,
            arguments: ["-m", "pip"] + arguments,
            environment: env,
            timeout: timeout
        )
    }

    private static func pipEnvironment() -> [String: String] {
        // Minimal env for pip: enough to run embedded interpreter and reach
        // the network, without inheriting the server's full environment.
        
        let scratch = NSTemporaryDirectory()
        var env: [String: String] = [
            "PATH": PythonEnv.pythonHome.appendingPathComponent("bin").path + ":/usr/bin:/bin",
            "HOME": scratch,
            "TMPDIR": scratch,
            "PYTHONHOME": PythonEnv.pythonHome.path,
            "PYTHONNOUSERSITE": "1",
            "LANG": "C.UTF-8",
        ]
        // Respect proxy settings if the host has them (common on managed networks).
        let inherited = ProcessInfo.processInfo.environment
        for key in ["HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY", "http_proxy", "https_proxy", "no_proxy"] {
            if let value = inherited[key] { env[key] = value }
        }
        return env
    }
    
    private static func isValidRequirement(_ spec: String) -> Bool {
        // name, optional [extras], optional comma-separated version specifiers.
        // Deliberately rejects:
        //  leading '-' (flags), '/', ':', '@' (paths, URLs, VCS and direct references), and whitespace
        
        let pattern = #"^[A-Za-z0-9]([A-Za-z0-9._-]*[A-Za-z0-9])?(\[[A-Za-z0-9._,-]+\])?\s*((==|!=|<=|>=|~=|<|>)\s*[A-Za-z0-9.*+!_-]+(\s*,\s*(==|!=|<=|>=|~=|<|>)\s*[A-Za-z0-9.*+!_-]+)*)?$"#
        return spec.range(of: pattern, options: .regularExpression) != nil
    }

    private static func appendToLedger(_ package: String) {
        let ledger = DAWSON.root.appendingPathComponent("python-installed-packages.txt")
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(stamp)  \(package)\n"
        if let handle = try? FileHandle(forWritingTo: ledger) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        } else {
            try? line.write(to: ledger, atomically: true, encoding: .utf8)
        }
    }

    private static func tail(_ s: String, lines: Int) -> String {
        s.split(separator: "\n", omittingEmptySubsequences: false)
            .suffix(lines)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

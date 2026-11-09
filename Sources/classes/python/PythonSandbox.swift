//
//  PythonSandbox.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/21/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

final class PythonSandbox {
    //  OS-level sandboxing for agent-initiated Python execution
    //
    //  macOS: Seatbelt profile via /usr/bin/sandbox-exec
    //  Linux: bubblewrap (bwrap) with mount + PID + (optionally) network namespaces
    //
    //  Design: deny-by-default. The child process may read bundled Python
    //  runtime and a small set of system paths, read/write only agent's
    //  workspace directories plus its scratch pad and a per-run temp dir, and
    //  (by default) has no network. If a sandbox cannot be constructed, we
    //  FAIL CLOSED — the script does not run.
    //
    //  Note: DAWSON.root contains secrets (TLS key, auth token, MemPalace data)
    //  as siblings of the Python home. Never allow DAWSON.root itself — only
    //  the specific python-* subdirectory and python-scripts.
    
    private init() {}
    
    static func makeProcess(invocation: [String], spec: SandboxSpec) throws -> Prepared {
        // Builds a ready-to-run (not yet launched) sandboxed Process
        // `invocation` is the full command, e.g. [pythonExecPath, "-c", bootstrap]
        
        guard (!invocation.isEmpty) else {
            throw SandboxError.setupFailed("empty invocation")
        }
        guard (!spec.writableDirectories.isEmpty) else {
            // Sandbox requires place to let script write, missing
            throw SandboxError.setupFailed("no workspace directories configured")
        }

        // Canonicalize all paths. Seatbelt matches on real paths
        // (/tmp -> /private/tmp on macOS), and bwrap binds resolve better too.
        var writable = spec.writableDirectories.map(FileUtilities.canonicalFilePath)
        let agentScratch = spec.scratchPath.map(FileUtilities.canonicalFilePath)
        if let agentScratch {
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: agentScratch), withIntermediateDirectories: true)
            writable.append(agentScratch)
        }
        let readOnly = spec.readOnlyDirectories.map(FileUtilities.canonicalFilePath)
        let executable = spec.executableDirectories.map(FileUtilities.canonicalFilePath)
        let pythonHome = FileUtilities.canonicalFilePath(PythonEnv.pythonHome.path)

        // Per-run temp dir: TMPDIR/HOME for the child, deleted afterwards.
        // (Distinct from the agent's persistent scratch pad.)
        let runTemp = try makeRunTempDirectory()

        let env = makeEnvironment(
            runTemp: runTemp.path,
            writable: writable,
            agentScratch: agentScratch,
            memoryLimitMB: spec.memoryLimitMB
        )

        #if os(macOS)
        let prepared = try makeMacProcess(
            invocation: invocation,
            pythonHome: pythonHome,
            writable: writable + [runTemp.path],
            readOnly: readOnly,
            executable: executable,
            allowNetwork: spec.allowNetwork,
            allowLoopback: spec.allowLoopback
        )
        #elseif os(Linux)
        let prepared = try makeLinuxProcess(
            invocation: invocation,
            pythonHome: pythonHome,
            writable: writable + [runTemp.path],
            readOnly: readOnly,
            executable: executable,
            allowNetwork: spec.allowNetwork
        )
        #else
        throw SandboxError.unsupportedPlatform
        #endif

        prepared.process.environment = env
        prepared.process.currentDirectoryURL = URL(fileURLWithPath: writable[0])

        let innerCleanup = prepared.cleanup
        return Prepared(
            process: prepared.process,
            scratchDirectory: runTemp,
            cleanup: {
                innerCleanup()
                try? FileManager.default.removeItem(at: runTemp)
            }
        )
    }
    
    private static func makeRunTempDirectory() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dawson-pyrun-\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            throw SandboxError.setupFailed("could not create run temp dir: \(error)")
        }
        return URL(fileURLWithPath: FileUtilities.canonicalFilePath(dir.path))
    }
    
    private static func makeEnvironment(
        runTemp: String,
        writable: [String],
        agentScratch: String?,
        memoryLimitMB: Int
    ) -> [String: String] {
        // Minimal, explicit environment.
        // Does NOT inherit server environment (which may contain secrets)
        
        let scriptsPath = DAWSON.root.appendingPathComponent("python-scripts").path
        // site-packages + shared scripts + the workspace (and scratch), agent-written modules living in either are importable.
        let pythonPath = ([PythonEnv.pythonPackagesPath, scriptsPath] + writable)
            .joined(separator: ":")

        var env: [String: String] = [
            // Preserve a minimal, deterministic command path without inheriting host environment variables.
            // Vendor toolchain bins go last so system tools always win.
            "PATH": ([PythonEnv.pythonHome.appendingPathComponent("bin").path, "/usr/bin", "/bin"]
                + DeveloperTools.hostToolchainBinPaths).joined(separator: ":"),
            "HOME": runTemp,
            "TMPDIR": runTemp,
            "PYTHONHOME": PythonEnv.pythonHome.path,
            "PYTHONPATH": pythonPath,
            "PYTHONSAFEPATH": "1",
            "PYTHONNOUSERSITE": "1",
            // The runtime is mounted read-only; don't try to write .pyc files.
            "PYTHONDONTWRITEBYTECODE": "1",
            "PYTHONUNBUFFERED": "1",
            "LANG": "C.UTF-8",
            // Read by the bootstrap prelude (resource.setrlimit).
            "DAWSON_MEM_LIMIT_MB": String(memoryLimitMB),
        ]
        if let agentScratch {
            env["DAWSON_SCRATCH"] = agentScratch
        }
        
        // Gradle: HOME is per-run temp, so without this every run gets a cold
        // (and, with network denied, unfillable) cache. Keep it in the
        // workspace so wrapper dists + dependency caches persist across runs.
        // Daemons would outlive the sandboxed run; forbid them.
        if let first = writable.first {
            env["GRADLE_USER_HOME"] = first + "/.gradle"
        }
        env["GRADLE_OPTS"] = "-Dorg.gradle.daemon=false"
        env["JAVA_TOOL_OPTIONS"] = "-Djava.net.preferIPv4Stack=true"   // Seatbelt's "localhost" doesn't match IPv4-mapped addresses
        
        env.merge(DeveloperTools.hostToolchainEnvironment) { _, pinned in pinned }
        
        return env
    }
}

extension PythonSandbox {
    
    struct Prepared {
        let process: Process
        let scratchDirectory: URL
        let cleanup: () -> Void
    }
}

extension PythonSandbox {
    // MARK: - macOS (Seatbelt via sandbox-exec)
    #if os(macOS)
    private static func sbEscape(_ path: String) -> String {
        return path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func seatbeltProfile(
        pythonHome: String,
        writable: [String],
        readOnly: [String],
        executable: [String],
        allowNetwork: Bool,
        allowLoopback: Bool
    ) -> String {
        let writableRules = writable
            .map { "(allow file-read* file-write* (subpath \"\(sbEscape($0))\"))" }
            .joined(separator: "\n")
        // Builds inherently execute workspace content (./gradlew, built test
        // binaries, configure scripts), so writable dirs are also exec-allowed.
        let writableExecRules = writable
            .map { "(subpath \"\(sbEscape($0))\")" }
            .joined(separator: "\n")
        let readOnlyRules = readOnly
            .map { "(allow file-read* (subpath \"\(sbEscape($0))\"))" }
            .joined(separator: "\n")
        let executableRules = executable
            .map { "(subpath \"\(sbEscape($0))\")" }
            .joined(separator: "\n")
        
        // Network tiers (most to least permissive):
        //  - allowNetwork:  full network.
        //  - allowLoopback: localhost TCP+UDP for build-tool IPC (Gradle/Kotlin
        //    daemons, test runners). macOS has no network namespaces, so this
        //    reaches EVERY host loopback service — the denies below fence off
        //    known unauthenticated ones (adb, debug probes, Chrome DevTools,
        //    Ollama, MySQL). Seatbelt is last-match-wins, so they must follow
        //    the allows. Dev servers / agent-to-agent traffic are NOT fenced.
        //  - neither:       loopback UDP only (Gradle's file-lock handler).
        let networkRule: String
        if (allowNetwork) {
            networkRule = "(allow network*)\n(allow system-socket)"
        } else if (allowLoopback) {
            // HAZARD: Gradle binds/listens on wildcard, so inbound is "*:*": agent-run servers can accept LAN connections.
            // Outbound stays loopback-only + port denies; the agent can't initiate off-machine traffic.
            // Mitigation: enable macOS Firewall ("Block all incoming connections").
            networkRule = """
              (allow network-bind (local ip "*:*"))
              (allow network-inbound (local ip "*:*"))
              (allow network-outbound (remote ip "localhost:*"))
              (deny network-outbound
                (remote tcp "localhost:5037")
                (remote tcp "localhost:2331")
                (remote tcp "localhost:3333")
                (remote tcp "localhost:4444")
                (remote tcp "localhost:9222")
                (remote tcp "localhost:11434")
                (remote tcp "localhost:3306")
                (remote tcp "localhost:1455")
                (remote tcp "localhost:8443"))   ; dawson-server + OpenAI OAuth callback — keep in sync
              """
        } else {
            networkRule = """
              (allow network-bind (local udp "localhost:*"))
              (allow network-inbound (local udp "localhost:*"))
              (allow network-outbound (remote udp "localhost:*"))
              """
        }

        return """
        (version 1)
        (deny default)

        ; --- process lifecycle ---
        (allow process-fork)
        (allow process-exec
          (subpath "\(sbEscape(pythonHome))")
          (subpath "/usr/lib")
          (subpath "/bin")
          (subpath "/usr/bin")
          \(executableRules)
          \(writableExecRules))
        (allow signal (target same-sandbox))

        ; --- baseline reads the interpreter/dyld/CoreFoundation need ---
        (allow file-read-metadata)
        (allow file-read* (literal "/"))
        (allow file-read*
          (subpath "\(sbEscape(pythonHome))")
          (subpath "/usr/lib")
          (subpath "/usr/share")
          (subpath "/System")
          (subpath "/private/etc")
          (subpath "/private/var/db/timezone")
          (literal "/dev/null")
          (literal "/dev/zero")
          (literal "/dev/random")
          (literal "/dev/urandom")
          (subpath "/dev/fd")
          \(executableRules))
        (allow file-write-data
          (literal "/dev/null")
          (subpath "/dev/fd"))
        (allow sysctl-read)
        ; Named services only — a blanket mach-lookup is the classic Seatbelt
        ; escape surface once arbitrary native code runs. This set covers what
        ; libSystem/CF, code-signature checks, and build tools (FSEvents for
        ; Gradle's file watching) actually need. If a toolchain breaks, find
        ; the missing service with:  log stream --predicate 'sender == "Sandbox"'
        (allow mach-lookup
          (global-name-regex #"^com\\.apple\\.system\\.")
          (global-name "com.apple.SecurityServer")
          (global-name "com.apple.trustd")
          (global-name "com.apple.trustd.agent")
          (global-name "com.apple.bsd.dirhelper")
          (global-name "com.apple.logd")
          (global-name "com.apple.diagnosticd")
          (global-name "com.apple.FSEvents"))

        ; --- workspace + scratch (read/write) ---
        \(writableRules)

        ; --- extras (read-only) ---
        \(readOnlyRules)

        ; --- network ---
        \(networkRule)
        """
    }

    private static func makeMacProcess(
        invocation: [String],
        pythonHome: String,
        writable: [String],
        readOnly: [String],
        executable: [String],
        allowNetwork: Bool,
        allowLoopback: Bool
    ) throws -> Prepared {
        let sandboxExec = "/usr/bin/sandbox-exec"
        guard FileManager.default.isExecutableFile(atPath: sandboxExec) else {
            throw SandboxError.sandboxUnavailable("\(sandboxExec) not found")
        }

        let profile = seatbeltProfile(
            pythonHome: pythonHome,
            writable: writable,
            readOnly: readOnly,
            executable: executable,
            allowNetwork: allowNetwork,
            allowLoopback: allowLoopback
        )

        let profileURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dawson-sb-\(UUID().uuidString).sb")
        do {
            try profile.write(to: profileURL, atomically: true, encoding: .utf8)
        } catch {
            throw SandboxError.setupFailed("could not write Seatbelt profile: \(error)")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: sandboxExec)
        process.arguments = ["-f", profileURL.path] + invocation

        return Prepared(
            process: process,
            scratchDirectory: profileURL, // unused placeholder; real temp set by caller
            cleanup: { try? FileManager.default.removeItem(at: profileURL) }
        )
    }
    #endif
}

extension PythonSandbox {
    // MARK: - Linux (bubblewrap)
    #if os(Linux)
    private static func findBwrap() -> String? {
        for candidate in ["/usr/bin/bwrap", "/usr/local/bin/bwrap", "/bin/bwrap"]
        where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }
        return nil
    }
    
    private static func makeLinuxProcess(
        invocation: [String],
        pythonHome: String,
        writable: [String],
        readOnly: [String],
        executable: [String],
        allowNetwork: Bool
    ) throws -> Prepared {
        guard let bwrap = findBwrap() else {
            throw SandboxError.sandboxUnavailable(
                "bubblewrap not found — install it (e.g. `apt install bubblewrap`)"
            )
        }

        let fm = FileManager.default
        var args: [String] = [
            "--die-with-parent",
            "--unshare-user", "--unshare-pid", "--unshare-ipc",
            "--unshare-uts", "--unshare-cgroup",
            "--proc", "/proc",
            "--dev", "/dev",
            "--tmpfs", "/tmp",
            // No --clearenv needed: Process.environment (set by the caller to a
            // minimal explicit dict) is exactly what bwrap inherits and passes on.
        ]
        if !allowNetwork {
            // Private network namespace: bwrap brings up its own `lo`, so
            // loopback IPC works with zero reach into host services.
            // SandboxSpec.allowLoopback is therefore a no-op here.
            args += ["--unshare-net"]
        }

        // Minimal system paths (shared libs / loader), read-only, only if present.
        var systemRO = ["/usr", "/lib", "/lib64", "/bin", "/sbin", "/etc/alternatives", "/etc/ld.so.cache"]
        if allowNetwork {
            systemRO += ["/etc/resolv.conf", "/etc/ssl", "/etc/hosts", "/etc/nsswitch.conf"]
        }
        for path in systemRO where fm.fileExists(atPath: path) {
            args += ["--ro-bind", path, path]
        }

        args += ["--ro-bind", pythonHome, pythonHome]
        for path in readOnly where fm.fileExists(atPath: path) {
            args += ["--ro-bind", path, path]
        }
        for path in executable where fm.fileExists(atPath: path) {
            args += ["--ro-bind", path, path]
        }
        for path in writable {
            args += ["--bind", path, path]
        }

        args += ["--"] + invocation

        let process = Process()
        process.executableURL = URL(fileURLWithPath: bwrap)
        process.arguments = args

        return Prepared(process: process, scratchDirectory: URL(fileURLWithPath: "/"), cleanup: {})
    }
    #endif
}

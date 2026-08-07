//
//  PythonHandler.swift
//  DAWSON
//
//  Created by Ethan Brown on 4/26/26.
//

import Foundation
import PythonKit

fileprivate final class PythonSerialThread: @unchecked Sendable {
    // Dedicated Python thread
    private let cond = NSCondition()
    private var jobs: [() -> Void] = []

    init() {
        Thread.detachNewThread { [self] in
            while true {
                cond.lock()
                while jobs.isEmpty { cond.wait() }
                let job = jobs.removeFirst()
                cond.unlock()
                job()
            }
        }
    }

    func sync<T>(_ body: @escaping () throws -> T) throws -> T {
        var result: Result<T, Error>!
        let sem = DispatchSemaphore(value: 0)
        cond.lock()
        jobs.append { result = Result { try body() }; sem.signal() }
        cond.signal()
        cond.unlock()
        sem.wait()
        return try result.get()
    }
}

class PythonHandler: @unchecked Sendable {
    static let shared = PythonHandler()
    
    static let scriptsPath = DAWSON.root.appendingPathComponent("python-scripts")
    
    private var sys: PythonObject?
    private let pyThread = PythonSerialThread()
    
    private init() {}
    
    private func ensurePython() throws {
        if (sys != nil) { return }
        
        let sysModule = try Python.attemptImport("sys")
        sysModule.path.insert(0, PythonEnv.pythonPackagesPath)
        sysModule.path.insert(0, PythonEnv.pythonHome.path)
        sysModule.path.insert(0, PythonHandler.scriptsPath.path)
        
        let os = try Python.attemptImport("os")
        os.environ.pop("PYTHONPATH", Python.None)
        
        sys = sysModule
    }
    
    private func callRaw(moduleName: String, functionName: String, args: [String: Any]) throws -> PythonObject {
        // Main Python calls (run ONLY on Python thread)
        try ensurePython()

        let module: PythonObject
        do {
            module = try Python.attemptImport(moduleName)
        } catch {
            throw PythonError.moduleNotFound("\(moduleName), error: \(error)")
        }

        let pyArgs = try PythonUtilities.toPython(args)

        guard let function = module.checking[dynamicMember: functionName] else {
            throw PythonError.functionNotFound(functionName)
        }
        let result = try function.throwing.dynamicallyCall(withArguments: pyArgs)

        // Detect Python-side exceptions
        let builtins = try Python.attemptImport("builtins")
        if Bool(builtins.isinstance(result, builtins.BaseException)) == true {
            throw PythonError.pythonExecutionFailed(String(describing: result))
        }

        return result
    }

    func callString(moduleName: String, functionName: String, args: [String: Any] = [:]) throws -> String {
        // Returns String-based Python result
        return try pyThread.sync {
            String(describing: try self.callRaw(moduleName: moduleName, functionName: functionName, args: args))
        }
    }

    func callStructured(moduleName: String, functionName: String, args: [String: Any] = [:]) throws -> Any {
        // Returns Swift Any-based Python result
        return try pyThread.sync {
            PythonUtilities.fromPython(try self.callRaw(moduleName: moduleName, functionName: functionName, args: args))
        }
    }
}

extension PythonHandler {
    func startPythonProcess(
        scriptPath: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        inputPipe: Pipe,
        outputPipe: Pipe,
        errorPipe: Pipe
    ) throws -> PythonProcess {
        try ensurePython()
        
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            throw PythonError.invalidScriptPath(scriptPath)
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: PythonEnv.pythonExecPath)
        process.arguments = [scriptPath] + arguments

        var env = ProcessInfo.processInfo.environment
        env["PYTHONHOME"] = PythonEnv.pythonHome.path
        env["PYTHONPATH"] = PythonEnv.pythonPackagesPath
        env["PYTHONSAFEPATH"] = "1"

        if let extraEnv = environment {
            for (k, v) in extraEnv {
                env[k] = v
            }
        }

        process.environment = env
        process.standardInput = inputPipe.fileHandleForWriting
        process.standardOutput = outputPipe.fileHandleForReading
        process.standardError = errorPipe.fileHandleForWriting

        do {
            try process.run()
        } catch {
            throw PythonError.processFailed(error.localizedDescription)
        }

        return PythonProcess(
            process: process,
            pid: process.processIdentifier
        )
    }

    func isRunning(_ handle: PythonProcess) -> Bool {
        return handle.process.isRunning
    }

    func stop(_ handle: PythonProcess) {
        handle.process.terminate()
    }
}

extension PythonHandler {
    
    func runSandboxed(
        payload: Data,
        spec: SandboxSpec
    ) throws -> SandboxedResult {
        // Runs (blocking) module.function(**args) Python funcs in sandboxed subprocess
        let invocation = [
            PythonEnv.pythonExecPath,
            "-c", PythonUtilities.moduleBootstrap(memoryLimitMB: spec.memoryLimitMB)
        ]
        return try launchSandboxed(invocation: invocation, spec: spec, stdinData: payload)
    }
    
    func runSandboxedScript(
        scriptPath: String,
        arguments: [String] = [],
        spec: SandboxSpec
    ) throws -> SandboxedResult {
        // Runs Python file (top-bottom) sandboxed
        let invocation = [
            PythonEnv.pythonExecPath,
            "-c", PythonUtilities.scriptRunner(memoryLimitMB: spec.memoryLimitMB),
            scriptPath
        ] + arguments
        return try launchSandboxed(invocation: invocation, spec: spec, stdinData: nil)
    }
    
    private func launchSandboxed(
        invocation: [String],
        spec: SandboxSpec,
        stdinData: Data?
    ) throws -> SandboxedResult {
        
        let prepared = try PythonSandbox.makeProcess(invocation: invocation, spec: spec)
        defer { prepared.cleanup() }
        
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        // Assign the Pipe objects directly — Foundation wires the correct ends.
        prepared.process.standardInput = stdinPipe
        prepared.process.standardOutput = stdoutPipe
        prepared.process.standardError = stderrPipe
        
        do {
            try prepared.process.run()
        } catch {
            throw PythonError.processFailed(error.localizedDescription)
        }
        
        // Send any payload, then close stdin (json.load(sys.stdin) needs EOF).
        if let stdinData {
            stdinPipe.fileHandleForWriting.write(stdinData)
        }
        try? stdinPipe.fileHandleForWriting.close()
        
        // Drain stdout/stderr on background queues WHILE the process runs.
        // (Reading only after exit can deadlock if the child fills the pipe.)
        var outData = Data()
        var errData = Data()
        let drainGroup = DispatchGroup()
        drainGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            drainGroup.leave()
        }
        drainGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            drainGroup.leave()
        }
        
        // Wall-clock timeout: terminate, then SIGKILL if it ignores.
        var timedOut = false
        let exitSem = DispatchSemaphore(value: 0)
        prepared.process.terminationHandler = { _ in
            exitSem.signal()
        }
        
        if exitSem.wait(timeout: .now() + spec.timeout) == .timedOut {
            timedOut = true
            prepared.process.terminate()
            if exitSem.wait(timeout: .now() + 3) == .timedOut {
                kill(prepared.process.processIdentifier, SIGKILL)
                _ = exitSem.wait(timeout: .now() + 3)
            }
        }
        drainGroup.wait()
        
        return SandboxedResult(
            exitCode: prepared.process.terminationStatus,
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? "",
            timedOut: timedOut
        )
    }
}

extension PythonHandler {
    
    func runSandboxedCommand(
        shellCommand: String,
        workingDirectory: String,
        spec: SandboxSpec
    ) throws -> SandboxedResult {
        // Runs a shell command confined by the OS sandbox to the spec's
        // writable directories, with the given working directory.
        
        // The shell itself must be executable inside the sandbox. On macOS
        // /bin/sh is covered by the system read rules; on Linux it's under
        // /bin which the bwrap profile ro-binds. We invoke it by absolute
        // path so no PATH resolution is needed.
        let invocation = ["/bin/sh", "-c", shellCommand]

        // The working directory must be one of the writable dirs
        var effectiveSpec = spec
        if (!effectiveSpec.writableDirectories.contains(workingDirectory)) {
            effectiveSpec.writableDirectories.append(workingDirectory)
        }

        let prepared = try PythonSandbox.makeProcess(invocation: invocation, spec: effectiveSpec)
        defer { prepared.cleanup() }

        // Run the command with cwd set inside the sandbox by prepending a cd.
        // (PythonSandbox sets currentDirectoryURL to writable[0]; this cd's to the
        // requested dir explicitly so relative paths resolve as the user expects.)
        prepared.process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        prepared.process.standardInput = FileHandle.nullDevice
        prepared.process.standardOutput = stdoutPipe
        prepared.process.standardError = stderrPipe

        do {
            try prepared.process.run()
        } catch {
            throw PythonError.processFailed(error.localizedDescription)
        }

        var outData = Data()
        var errData = Data()
        let drainGroup = DispatchGroup()
        drainGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            drainGroup.leave()
        }
        drainGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            drainGroup.leave()
        }

        var timedOut = false
        let exitSem = DispatchSemaphore(value: 0)
        prepared.process.terminationHandler = { _ in exitSem.signal() }

        if exitSem.wait(timeout: .now() + spec.timeout) == .timedOut {
            timedOut = true
            prepared.process.terminate()
            if exitSem.wait(timeout: .now() + 3) == .timedOut {
                kill(prepared.process.processIdentifier, SIGKILL)
                _ = exitSem.wait(timeout: .now() + 3)
            }
        }
        drainGroup.wait()

        return SandboxedResult(
            exitCode: prepared.process.terminationStatus,
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? "",
            timedOut: timedOut
        )
    }
}


//
//  HostProcess.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/21/26.
//

import Foundation

final class HostProcess {
    
    // Used for HOST-SIDE processes (no sandbox)
    // Use for permission-gated operations (e.g. pip installs, syntax checks)
    // Do NOT use for agent-authored code

    private init() {}

    static func run(
        executable: String,
        arguments: [String],
        environment: [String: String]? = nil,
        currentDirectory: URL? = nil,
        timeout: TimeInterval
    ) throws -> HostProcessResult {

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let environment { process.environment = environment }
        if let currentDirectory { process.currentDirectoryURL = currentDirectory }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        // Drain while running to avoid pipe-buffer deadlocks.
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
        process.terminationHandler = { _ in exitSem.signal() }

        if exitSem.wait(timeout: .now() + timeout) == .timedOut {
            timedOut = true
            process.terminate()
            if exitSem.wait(timeout: .now() + 3) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                _ = exitSem.wait(timeout: .now() + 3)
            }
        }
        drainGroup.wait()

        return HostProcessResult(
            exitCode: process.terminationStatus,
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? "",
            timedOut: timedOut
        )
    }
}

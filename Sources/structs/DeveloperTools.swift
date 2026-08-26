//
//  DeveloperTools.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/23/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

struct DeveloperTools {
    private static let cltPath = "/Library/Developer/CommandLineTools"
    
    static let hostToolchainPaths: [String] = {
        // Directories containing host dev toolchain, suitable for
        // read+exec grants in sandbox (SandboxSpec.executableDirectories).
        // Vendor-distributed tools/SDKs only — no user data or secrets.
        
        // macOS: prefer standalone Command Line Tools — self-contained (no
        //   external @rpath frameworks) and no license gate, so sandboxed tools
        //   never depend on Xcode's install/license state. Fall back to the
        //   xcode-select'd directory (widened to the .app bundle root, whose
        //   tools link frameworks outside Contents/Developer) only when CLT is
        //   absent. Vendor-distributed content only; no user data or secrets.
        // Linux: toolchains live under baseline system paths already exposed
        //   by the sandbox, so nothing extra is granted.

        #if os(macOS)
        if FileManager.default.fileExists(atPath: cltPath + "/usr/bin/git") {
            return [cltPath]
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        p.arguments = ["-p"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
        } catch {
            return []
        }
        p.waitUntilExit()
        guard (p.terminationStatus == 0) else { return [] }
        
        let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard (!out.isEmpty) else { return [] }
        
        let dev = FileUtilities.canonicalFilePath(out)
        if dev.hasSuffix(".app/Contents/Developer") {
            return [String(dev.dropLast("/Contents/Developer".count))]
        }
        return [dev]
        #else
        return []
        #endif
    }()
    
    static let hostToolchainEnvironment: [String: String] = {
        #if os(macOS)
        if (hostToolchainPaths.first == cltPath) {
            // xcrun honors DEVELOPER_DIR over xcode-select, so commands
            // resolve into CLT even when the host selects full Xcode.
            return ["DEVELOPER_DIR": cltPath]
        }
        #endif
        return [:]
    }()
}

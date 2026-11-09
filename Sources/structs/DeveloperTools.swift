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
    
    static let hostJavaHome: String? = {
        // macOS: the system-selected JDK home via /usr/libexec/java_home.
        // Vendor-distributed SDK only — suitable for a read+exec grant.
        #if os(macOS)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/libexec/java_home")
        p.arguments = []
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
        } catch {
            return nil
        }
        p.waitUntilExit()
        guard (p.terminationStatus == 0) else { return nil }
        let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!out.isEmpty) else { return nil }
        return FileUtilities.canonicalFilePath(out)
        #else
        return nil   // Linux: JDKs live under baseline system paths the sandbox exposes.
        #endif
    }()
    
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
        let java = hostJavaHome.map { [$0] } ?? []
        if FileManager.default.fileExists(atPath: cltPath + "/usr/bin/git") {
            return [cltPath] + java + vendorRoots
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
            return java + vendorRoots
        }
        p.waitUntilExit()
        guard (p.terminationStatus == 0) else { return java + vendorRoots }
        
        let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard (!out.isEmpty) else { return java + vendorRoots }
        
        let dev = FileUtilities.canonicalFilePath(out)
        if dev.hasSuffix(".app/Contents/Developer") {
            return [String(dev.dropLast("/Contents/Developer".count))] + java + vendorRoots
        }
        return [dev] + java + vendorRoots
        #else
        return vendorRoots
        #endif
    }()
    
    private static let vendorRoots: [String] = {
        // Vendor-installed toolchain roots (SES, MPLAB X + XC compilers, Homebrew, ARM GNU) — read+exec grants only; no user data lives here.
        let fm = FileManager.default
        #if os(macOS)
        // Deliberately NOT /opt/homebrew wholesale — grant specific brew kegs
        // case-by-case here if needed (e.g. "/opt/homebrew/opt/cmake").
        var candidates = ["/Applications/microchip"]
        // Versioned vendor folders (e.g. "SEGGER Embedded Studio for ARM 8.22a").
        if let apps = try? fm.contentsOfDirectory(atPath: "/Applications") {
            candidates += apps
                .filter { $0.hasPrefix("SEGGER Embedded Studio") || $0.hasPrefix("ArmGNUToolchain") }
                .map { "/Applications/" + $0 }
        }
        #else
        var candidates = ["/opt/microchip"]
        if let opt = try? fm.contentsOfDirectory(atPath: "/opt") {
            candidates += opt
                .filter { $0.lowercased().contains("segger") }
                .map { "/opt/" + $0 }
        }
        #endif
        var roots: [String] = []
        for candidate in candidates {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: candidate, isDirectory: &isDir), isDir.boolValue {
                roots.append(FileUtilities.canonicalFilePath(candidate))
            }
        }
        return roots
    }()
    
    static let hostToolchainBinPaths: [String] = {
        // bin directories inside the vendor roots, appended to the sandbox
        // PATH so bare invocations (emBuild, prjMakefilesGenerator.sh, cmake)
        // resolve without absolute paths.
        return vendorRoots.flatMap { binDirectories(under: $0) }
    }()
    
    private static func binDirectories(under root: String, maxDepth: Int = 4) -> [String] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        let direct = root + "/bin"
        if fm.fileExists(atPath: direct, isDirectory: &isDir), isDir.boolValue {
            // A top-level bin (Homebrew, SES) is the whole story; don't walk
            // the rest (Homebrew's Cellar is enormous).
            return [direct]
        }
        // Shallow walk for nested bins (e.g. mplabx/v6.20/mplab_platform/bin,
        // xc32/v4.35/bin).
        var found: [String] = []
        func walk(_ dir: String, depth: Int) {
            guard (depth < maxDepth), let entries = try? fm.contentsOfDirectory(atPath: dir) else { return }
            for entry in entries {
                let path = dir + "/" + entry
                var d: ObjCBool = false
                guard fm.fileExists(atPath: path, isDirectory: &d), d.boolValue else { continue }
                if (entry == "bin") {
                    found.append(path)
                } else {
                    walk(path, depth: depth + 1)
                }
            }
        }
        walk(root, depth: 0)
        return found
    }
    
    static let hostToolchainEnvironment: [String: String] = {
        var env: [String: String] = [:]
        #if os(macOS)
        if (hostToolchainPaths.first == cltPath) {
            // xcrun honors DEVELOPER_DIR over xcode-select, so commands
            // resolve into CLT even when the host selects full Xcode.
            env["DEVELOPER_DIR"] = cltPath
        }
        if let javaHome = hostJavaHome {
            // gradlew and friends resolve java via JAVA_HOME first.
            env["JAVA_HOME"] = javaHome
        }
        #endif
        return env
    }()
}

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
    
    static let hostAndroidSDK: String? = {
        // Android SDK (read-only is enough for AGP builds). Standard install
        // locations; honor ANDROID_HOME if the server was launched with one.
        let fm = FileManager.default
        var candidates: [String] = []
        if let env = ProcessInfo.processInfo.environment["ANDROID_HOME"], (!env.isEmpty) {
            candidates.append(env)
        }
        #if os(macOS)
        candidates.append(NSHomeDirectory() + "/Library/Android/sdk")
        #else
        candidates.append(NSHomeDirectory() + "/Android/Sdk")
        #endif
        for candidate in candidates {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: candidate + "/platforms", isDirectory: &isDir), isDir.boolValue {
                return FileUtilities.canonicalFilePath(candidate)
            }
        }
        return nil
    }()
    
    private static let jdkRoots: [String] = {
        // Where macOS JDKs install. Gradle's toolchain detection scans these and
        // probes JDKs via their (often symlinked) paths here, so grant the
        // directories as-is, not only the canonical java_home. Kept out of
        // vendorRoots so JDK bins don't land on the sandbox PATH.
        #if os(macOS)
        return ["/Library/Java/JavaVirtualMachines",
                NSHomeDirectory() + "/Library/Java/JavaVirtualMachines"]
            .filter { FileManager.default.fileExists(atPath: $0) }
        #else
        return []
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
        let java = (hostJavaHome.map { [$0] } ?? []) + jdkRoots
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
        var candidates = ["/Applications/microchip", "/Applications/SEGGER"]
        if let sdk = hostAndroidSDK { candidates.append(sdk) }
        // Versioned vendor folders (e.g. "SEGGER Embedded Studio for ARM 8.22a").
        if let apps = try? fm.contentsOfDirectory(atPath: "/Applications") {
            candidates += apps
                .filter { $0.hasPrefix("SEGGER Embedded Studio") || $0.hasPrefix("ArmGNUToolchain") }
                .map { "/Applications/" + $0 }
        }
        #else
        var candidates = ["/opt/microchip"]
        if let sdk = hostAndroidSDK { candidates.append(sdk) }
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
        
        if let sdk = hostAndroidSDK {
            // AGP resolves the SDK via ANDROID_HOME when local.properties is
            // absent/unreadable (it is: HOME is the per-run temp).
            env["ANDROID_HOME"] = sdk
            env["ANDROID_SDK_ROOT"] = sdk
        }
        return env
    }()
}

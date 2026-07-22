//
//  CommandClassifier.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/22/26.
//

import Foundation

final class CommandClassifier {
    // Determines which commands are safe, denied, require user (one-time per workspace) approval
    // Classifier determines based on command intent, all still require running in a sandbox
    
    private init() {}

    // Unambiguously benign: inspect/read/build/test. No approval in Warrior.
    static let safeExecutables: Set<String> = [
        "ls", "cat", "grep", "egrep", "fgrep", "find", "wc", "head", "tail",
        "echo", "pwd", "tree", "file", "stat", "du", "df", "diff", "sort",
        "uniq", "cut", "awk", "sed", "which", "basename", "dirname", "realpath",
        "swift", "swiftc", "node", "npm", "npx", "python3", "cargo", "rustc",
        "make", "cmake", "go", "javac", "java", "kotlin", "gradle", "date", "env"
    ]

    // Bad-intent signals: refused below Ultimate (even sandboxed).
    // Privilege escalation, destructive ops, network fetch-and-exec, and package
    // managers (which route through .install instead).
    static let deniedExecutables: [String: String] = [
        "sudo": "privilege escalation",
        "su": "privilege escalation",
        "doas": "privilege escalation",
        "rm": "destructive deletion",
        "rmdir": "destructive deletion",
        "dd": "raw disk write",
        "mkfs": "filesystem format",
        "shred": "destructive deletion",
        "chmod": "permission change",
        "chown": "ownership change",
        "curl": "network fetch (use fetch_url)",
        "wget": "network fetch (use fetch_url)",
        "ssh": "remote access",
        "scp": "remote transfer",
        "sftp": "remote transfer",
        "nc": "raw networking",
        "ncat": "raw networking",
        "telnet": "raw networking",
        "kill": "process control",
        "killall": "process control",
        "pkill": "process control",
        "shutdown": "system control",
        "reboot": "system control",
        "halt": "system control",
        "pip": "package install (use install_python_package)",
        "pip3": "package install (use install_python_package)",
        "brew": "package install (use the install action)",
        "apt": "package install (use the install action)",
        "apt-get": "package install (use the install action)",
        "yum": "package install",
        "dnf": "package install",
        "pacman": "package install",
        "gem": "package install",
        "cargo-install": "package install"
    ]

    // Read-only git subcommands are safe; mutating git is prompt-level.
    static let safeGitSubcommands: Set<String> = [
        "status", "diff", "log", "show", "branch", "remote", "ls-files",
        "blame", "rev-parse", "describe", "config"
    ]

    static func classify(_ command: String, userAllowed: Set<String>) -> CommandClass {
        // Classifies full command string.
        // `userAllowed` is per-user learned allowlist (grown by "always allow" approvals).
        
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!trimmed.isEmpty) else {
            return .denied(reason: "empty command")
        }

        // Refuse shell metacharacters that chain/obfuscate. These don't defeat
        // the sandbox, but a command using them can't be meaningfully
        // classified by its first token, so it must go through prompt-level
        // review at minimum — and pipes into shells are a denial.
        let dangerousChains = ["| sh", "|sh", "| bash", "|bash", "&& sudo", "; sudo"]
        for pattern in dangerousChains where trimmed.contains(pattern) {
            return .denied(reason: "pipes command into a shell")
        }

        let firstToken = trimmed.split(separator: " ").first.map(String.init) ?? trimmed
        let exe = (firstToken as NSString).lastPathComponent

        if let reason = deniedExecutables[exe] {
            return .denied(reason: reason)
        }

        if (exe == "git") {
            let tokens = trimmed.split(separator: " ").map(String.init)
            if (tokens.count > 1 && safeGitSubcommands.contains(tokens[1])) {
                return .safe
            }
            return .prompt   // git commit/push/etc — one approval, sandboxed
        }

        if (safeExecutables.contains(exe) || userAllowed.contains(exe)) {
            return .safe
        }

        return .prompt   // unknown: contained by sandbox, gets one approval
    }
}

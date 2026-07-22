//
//  CommandClassifier.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/22/26.
//

import Foundation

final class CommandClassifier {
    // Determines which commands are read, write, denied, require user (one-time per workspace) approval
    // Classifier determines based on command intent, all still require running in a sandbox
    
    private init() {}
    
    static let readExecutables: Set<String> = [
        "ls", "cat", "grep", "egrep", "fgrep", "find", "wc", "head", "tail",
        "echo", "pwd", "tree", "file", "stat", "du", "df", "diff", "sort",
        "uniq", "cut", "awk", "which", "basename", "dirname", "realpath",
        "date", "env"
    ]
    
    static let writeExecutables: Set<String> = [
        "sed", "swift", "swiftc", "node", "npm", "npx", "python3",
        "cargo", "rustc", "make", "cmake", "go", "javac", "java",
        "kotlin", "gradle", "tar", "zip", "unzip", "cp", "mv", "mkdir", "touch"
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
        "brew": "package install",
        "apt": "package install",
        "apt-get": "package install",
        "yum": "package install",
        "dnf": "package install",
        "pacman": "package install",
        "gem": "package install",
        "cargo-install": "package install"
    ]

    // Read-only git subcommands are observes
    // Everything else mutating git is a write (commit/push/checkout/etc)
    static let readGitSubcommands: Set<String> = [
        "status", "diff", "log", "show", "branch", "remote", "ls-files",
        "blame", "rev-parse", "describe", "config"
    ]

    static func classify(_ command: String, userAllowed: Set<String>) -> CommandClass {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!trimmed.isEmpty) else {
            return .denied(reason: "empty command")
        }

        // Pipe-into-shell and chained-sudo can't be classified by first token.
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
            if (tokens.count > 1 && readGitSubcommands.contains(tokens[1])) {
                return .read
            }
            return .write   // commit/push/checkout — mutating, one approval in Fledgling
        }

        if (readExecutables.contains(exe)) {
            return .read
        }

        // User-taught allowlist grants observe-level trust to a named exe.
        if (writeExecutables.contains(exe) || userAllowed.contains(exe)) {
            return .write
        }

        return .prompt   // unknown: force explicit approval, then run sandboxed
    }
}

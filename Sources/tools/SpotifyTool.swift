//
//  SpotifyTool.swift
//  
//
//  Created by Ethan Brown on 3/31/26.
//

import Foundation

class SpotifyTool: Tool {
    let name = "spotify_tool"

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Interact with Spotify client or Web API: play, pause, search songs, create playlists, etc.",
                "parameters": [
                    "type": "object",
                    "required": ["action"],
                    "properties": [
                        "action": [
                            "type": "string",
                            "description": "Action to perform: play, pause, next, previous, search, create_playlist"
                        ],
                        "query": [
                            "type": "string",
                            "description": "Search query for songs/albums/playlists (required for search/create_playlist)"
                        ],
                        "playlist_name": [
                            "type": "string",
                            "description": "Name for new playlist (required for create_playlist)"
                        ]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) -> String {
        guard let action = args["action"] as? String else {
            return "Error: 'action' is required."
        }

        #if os(macOS)
        return executeMac(action: action, args: args)
        #elseif os(Linux)
        return executeLinux(action: action, args: args)
        #elseif os(Windows)
        return executeWindows(action: action, args: args)
        #else
        return "Spotify control not supported on this platform."
        #endif
    }

    // MARK: - macOS Implementation
    #if os(macOS)
    private func executeMac(action: String, args: [String: Any]) -> String {
        let appleScript: String

        switch action.lowercased() {
        case "play":
            appleScript = "tell application \"Spotify\" to play"
        case "pause":
            appleScript = "tell application \"Spotify\" to pause"
        case "next":
            appleScript = "tell application \"Spotify\" to next track"
        case "previous":
            appleScript = "tell application \"Spotify\" to previous track"
        case "search":
            guard let query = args["query"] as? String else { return "Error: 'query' is required for search" }
            appleScript = """
            tell application "Spotify"
                set results to search "\(query)"
                return results
            end tell
            """
        case "create_playlist":
            guard let name = args["playlist_name"] as? String else { return "Error: 'playlist_name' is required" }
            appleScript = "tell application \"Spotify\" to make new playlist with properties {name:\"\(name)\"}"
        default:
            return "Unsupported action."
        }

        return runAppleScript(appleScript)
    }

    private func runAppleScript(_ script: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do { try process.run() } catch { return "Failed to run AppleScript: \(error)" }
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    #endif

    // MARK: - Linux Implementation (using dbus or spotifyd)
    #if os(Linux)
    private func executeLinux(action: String, args: [String: Any]) -> String {
        // Requires spotifyd or playerctl installed
        let command: String
        switch action.lowercased() {
        case "play": command = "playerctl play"
        case "pause": command = "playerctl pause"
        case "next": command = "playerctl next"
        case "previous": command = "playerctl previous"
        case "search":
            return "Search via Web API recommended on Linux"
        case "create_playlist":
            return "Create playlist via Web API recommended on Linux"
        default:
            return "Unsupported action."
        }
        return runShellCommand(command)
    }
    #endif

    // MARK: - Windows Implementation (via Spotify Web API or Win32 COM)
    #if os(Windows)
    private func executeWindows(action: String, args: [String: Any]) -> String {
        return "Local Spotify control on Windows requires Web API integration or third-party tools (like Spotify CLI)."
    }
    #endif

    // MARK: - Helper: Run shell command
    private func runShellCommand(_ command: String) -> String {
        let process = Process()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        #if os(Windows)
        process.executableURL = URL(fileURLWithPath: "cmd.exe")
        process.arguments = ["/C", command]
        #else
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        #endif

        do { try process.run() } catch { return "Failed to run command: \(error)" }
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

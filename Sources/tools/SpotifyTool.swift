//
//  SpotifyTool.swift
//  
//
//  Created by Ethan Brown on 3/31/26.
//

import Foundation
import Vapor

class SpotifyTool: PermissionAware {
    let name = "spotify_tool"
    
    func permissionRequests(args: [String : Any]) -> [PermissionRequest] {
        return [
            PermissionRequest(action: .command)
        ]
    }

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

    func execute(args: [String: Any]) async -> String {
        guard let action = args["action"] as? String else {
            return "Error: 'action' is required."
        }
        
        #if os(macOS)
        return executeMac(action: action, args: args)
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
}

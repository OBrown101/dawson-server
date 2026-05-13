//
//  FileSearch.swift
//  
//
//  Created by Ethan Brown on 3/31/26.
//

import Foundation

class FileSearch: Tool {
    let name = "file_search"
    
    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Searches for files by name or pattern across the system efficiently using system commands when available (Mac, Windows, Linux).",
                "parameters": [
                    "type": "object",
                    "required": ["filename", "path"],
                    "properties": [
                        "filename": [
                            "type": "string",
                            "description": "Name or pattern of the file to search for (supports wildcards, e.g., '*.txt')"
                        ],
                        "path": [
                            "type": "string",
                            "description": "Root path to start the search from (e.g., '/' on Linux/Mac or 'C:\\' on Windows)"
                        ]
                    ]
                ]
            ]
        ]
    }
    
    func execute(args: [String: Any]) async -> String {
        guard let filename = args["filename"] as? String,
              let path = args["path"] as? String else {
            return "Error: Missing filename or path."
        }
        
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else {
            return "Error: Path does not exist."
        }
        
        var results: [String] = []
        
        func runSystemCommand(_ command: [String]) -> [String] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command[0])
            process.arguments = Array(command.dropFirst())
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            
            do {
                try process.run()
            } catch {
                return []
            }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.components(separatedBy: "\n").filter { !$0.isEmpty }
        }
        
        #if os(macOS)
        // Use mdfind for fast search on Mac
        if isDir.boolValue {
            results = runSystemCommand(["/usr/bin/mdfind", "-onlyin", path, "kMDItemFSName == '\(filename)'"])
        } else if (path as NSString).lastPathComponent.lowercased() == filename.lowercased() {
            results = [path]
        }
        #elseif os(Linux)
        // Use find command on Linux
        if isDir.boolValue {
            results = runSystemCommand(["/usr/bin/find", path, "-type", "f", "-name", filename])
        } else if (path as NSString).lastPathComponent.lowercased() == filename.lowercased() {
            results = [path]
        }
        #elseif os(Windows)
        // Use PowerShell for fast search on Windows
        if isDir.boolValue {
            results = runSystemCommand(["C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
                                        "-Command",
                                        "Get-ChildItem -Path '\(path)' -Recurse -File -Filter '\(filename)' | ForEach-Object { $_.FullName }"])
        } else if (path as NSString).lastPathComponent.lowercased() == filename.lowercased() {
            results = [path]
        }
        #endif
        
        // Fallback to pure Swift recursive search if system command failed
        if results.isEmpty {
            func matchesPattern(_ fileName: String, pattern: String) -> Bool {
                let regexPattern = "^" + NSRegularExpression.escapedPattern(for: pattern)
                    .replacingOccurrences(of: "\\*", with: ".*")
                    .replacingOccurrences(of: "\\?", with: ".") + "$"
                return (try? NSRegularExpression(pattern: regexPattern, options: [.caseInsensitive])
                    .firstMatch(in: fileName, options: [], range: NSRange(location: 0, length: fileName.count))) != nil
            }
            
            func searchDirectory(_ dirPath: String) {
                guard let items = try? fm.contentsOfDirectory(atPath: dirPath) else { return }
                for item in items {
                    let fullPath = (dirPath as NSString).appendingPathComponent(item)
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: fullPath, isDirectory: &isDir) {
                        if isDir.boolValue {
                            searchDirectory(fullPath)
                        } else {
                            if matchesPattern(item, pattern: filename) {
                                results.append(fullPath)
                            }
                        }
                    }
                }
            }
            
            if isDir.boolValue {
                searchDirectory(path)
            } else {
                let fileNameOnly = (path as NSString).lastPathComponent
                if matchesPattern(fileNameOnly, pattern: filename) {
                    results.append(path)
                }
            }
        }
        
        return results.isEmpty ? "No files found matching '\(filename)'." : results.joined(separator: "\n")
    }
}

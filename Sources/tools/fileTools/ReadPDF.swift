//
//  ReadPDF.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/15/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

final class ReadPDF: PermissionAware {
    static let name = "read_pdf"

    let description = """
    Reads text from a PDF file at an exact path. The path must be an absolute path or a valid path relative to the current working directory. Use find_file first if the PDF location is unknown. Supports optional 1-based page ranges.
    """
    
    var timeout: TimeInterval = 120 // PDF parsing of large documents can be slow

    func permissionRequests(args: [String: Any]) -> [PermissionRequest] {
        guard let path = args["path"] as? String,
              (!path.isEmpty) else { return [] }

        return [PermissionRequest(action: .read, target: path)]
    }
    
    let parametersSchema: [String: Any] =
        [
            "type": "object",
            "properties": [
                "path": ["type": "string", "description": "The PDF file to read"],
                "start_page": ["type": "integer", "description": "Starting page number, 1-based"],
                "end_page": ["type": "integer", "description": "Ending page number, 1-based and inclusive"],
                "max_pages": ["type": "integer", "description": "Maximum pages to read when end_page is omitted", "default": 10],
                "search": ["type": "string", "description": "Optional text to search for in the PDF"],
                "context_pages": ["type": "integer", "description": "Pages before/after search matches to include", "default": 0],
                "include_metadata": ["type": "boolean", "default": false],
                "include_outline": ["type": "boolean", "default": false],
                "include_links": ["type": "boolean", "default": false],
                "include_annotations": ["type": "boolean", "default": false],
                "include_forms": ["type": "boolean", "default": false],
                "include_attachments": ["type": "boolean", "default": false],
                "include_page_info": ["type": "boolean", "default": false],
                "extract_tables": ["type": "boolean", "default": false],
                "list_images": ["type": "boolean", "default": false]
            ],
            "required": ["path"]
        ]

    func openAISchema() -> [String: Any] {
        return [
            "type": "function",
            "name": ReadPDF.name,
            "description": description,
            "parameters": parametersSchema
        ]
    }

    func anthropicSchema() -> [String: Any] {
        return [
            "name": ReadPDF.name,
            "description": description,
            "input_schema": parametersSchema
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": ReadPDF.name,
                "description": description,
                "parameters": parametersSchema
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let path = args["path"] as? String,
              (!path.isEmpty) else { return "Error: No path provided." }

        let pdfURL = URL(fileURLWithPath: path).standardizedFileURL
        guard FileManager.default.fileExists(atPath: pdfURL.path) else {
            return "Error: PDF not found at '\(pdfURL.path)'. Use find_file to locate it, then pass the returned absolute path."
        }

        var pythonArgs: [String: Any] = ["path": pdfURL.path]
        
        for key in [
            "start_page",
            "end_page",
            "max_pages",
            "search",
            "context_pages",
            "include_metadata",
            "include_outline",
            "include_links",
            "include_annotations",
            "include_forms",
            "include_attachments",
            "include_page_info",
            "extract_tables",
            "list_images"
        ] {
            if let value = args[key] {
                pythonArgs[key] = value
            }
        }

        // Scratch dir doubles as sandbox's required writable directory.
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("dawson-pdf-\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        } catch {
            return "Error: Could not create scratch directory: \(error.localizedDescription)"
        }
        defer { try? FileManager.default.removeItem(at: scratch) }

        var spec = SandboxSpec(writableDirectories: [scratch.path])
        spec.readOnlyDirectories = [
            DAWSON.root.appendingPathComponent("python-scripts").path,
            pdfURL.deletingLastPathComponent().path
        ]
        spec.timeout = timeout

        let payloadData: Data
        do {
            payloadData = try JSONSerialization.data(withJSONObject: [
                "module": "pdf_reader",
                "function": "read_pdf",
                "args": ["args": pythonArgs]
            ])
        } catch {
            return "Error reading PDF: could not encode arguments: \(error)"
        }
        let sendableSpec = spec

        // runSandboxed blocks on subprocess; hop off the cooperative pool.
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try PythonHandler.shared.runSandboxed(
                    payload: payloadData,
                    spec: sendableSpec
                )
            }.value

            if (result.timedOut) {
                return "Error: PDF parsing timed out after \(Int(timeout))s. Try a narrower page range."
            }

            // Bootstrap prints exactly one JSON object as the last stdout line.
            if let line = result.stdout
                .split(separator: "\n", omittingEmptySubsequences: true)
                .last,
               let data = line.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                if obj["ok"] as? Bool == true {
                    return obj["result"].map { String(describing: $0) } ?? "None"
                }
                let err = obj["error"] as? String ?? "unknown Python error"
                return "Error reading PDF:\n\(err)"
            }

            return "Error reading PDF: parser exited with code \(result.exitCode). stderr: \(result.stderr.isEmpty ? "(empty)" : result.stderr)"
        } catch {
            return "Error reading PDF: \(error)"
        }
    }
}

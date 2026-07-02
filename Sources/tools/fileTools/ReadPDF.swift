//
//  ReadPDF.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/15/26.
//

import Foundation

final class ReadPDF: PermissionAware {
    let name = "read_pdf"

    let description = """
    Reads text from a PDF file at an exact path. The path must be an absolute path or a valid path relative to the current working directory. Use find_file first if the PDF location is unknown. Supports optional 1-based page ranges.
    """

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
            "name": name,
            "description": description,
            "parameters": parametersSchema
        ]
    }

    func anthropicSchema() -> [String: Any] {
        return [
            "name": name,
            "description": description,
            "input_schema": parametersSchema
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": parametersSchema
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let path = args["path"] as? String,
              (!path.isEmpty) else { return "Error: No path provided." }

        var pythonArgs: [String: Any] = ["path": path]

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

        do {
            let result = try PythonHandler.shared.call(
                moduleName: "pdf_reader",
                functionName: "read_pdf",
                args: pythonArgs
            )

            return String(describing: result)
        } catch {
            return "Error reading PDF: \(error)"
        }
    }
}

//  ReadImage.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/8/26.
//

import Foundation

class ReadImage: PermissionAware {
    let name = "read_image"
    let description = "Reads an image file from disk and returns an image attachment payload. Use this when the user asks you to inspect, analyze, describe, or include an image file from an allowed workspace. Supports jpg, jpeg, png, webp, and gif."

    func permissionRequests(args: [String : Any]) -> [PermissionRequest] {
        guard let path = args["path"] as? String,
              !path.isEmpty else { return [] }

        return [
            PermissionRequest(action: .read, target: path)
        ]
    }

    func openAISchema() -> [String : Any] {
        return [
            "type": "function",
            "name": name,
            "description": description,
            "parameters": [
                "type": "object",
                "required": ["path"],
                "properties": [
                    "path": [
                        "type": "string",
                        "description": "Absolute path to the image file to read"
                    ],
                    "max_size_bytes": [
                        "type": "integer",
                        "description": "Maximum image size in bytes after optional compression",
                        "default": 5242880
                    ],
                    "attempt_compression": [
                        "type": "boolean",
                        "description": "Whether to attempt image compression if the image is larger than max_size_bytes",
                        "default": true
                    ]
                ]
            ]
        ]
    }

    func anthropicSchema() -> [String : Any] {
        return [
            "name": name,
            "description": description,
            "input_schema": openAISchema()["parameters"] as? [String : Any] ?? [:]
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": openAISchema()["parameters"] as? [String : Any] ?? [:]
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let path = args["path"] as? String, !path.isEmpty else {
            return "Error: No path provided."
        }

        let maxSizeBytes = args["max_size_bytes"] as? Int
        let attemptCompression = args["attempt_compression"] as? Bool ?? true

        do {
            let attachment = try await ImageProcessor.shared.loadImageAsAttachment(
                fromFilePath: path,
                maxSizeBytes: maxSizeBytes,
                attemptCompression: attemptCompression
            )

            return """
            Image loaded successfully.

            Path: \(path)
            Mime Type: \(attachment.mimeType)
            Size: \(attachment.sizeBytes ?? 0) bytes

            The image has been attached to the conversation and is ready for analysis.
            """
        } catch {
            return "Error reading image: \(error.localizedDescription)"
        }
    }
}

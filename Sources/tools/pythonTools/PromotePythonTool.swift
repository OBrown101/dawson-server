//
//  PromotePythonTool.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/21/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

class PromotePythonTool: PermissionAware {
    // Used to promote 'proven' Python module from workspace scratch/
    // to DAWSON shared python-scripts/.
    // On success:
    //    - archives any overwritten previous version to python-scripts/.archive/
    //    - regenerates python-scripts/catalog.json (tool discovery)
    //    - records the promotion in shared memory via `memoryRecorder`
    
    //  Security notes:
    //  - The SOURCE must resolve inside the agent's workspace (canonical-path
    //    prefix check, symlinks resolved).
    //  - The DESTINATION name is restricted to a bare Python identifier, so it
    //    cannot traverse outside python-scripts.
    //  - The file is syntax-checked with ast.parse (parses only — never
    //    executes) before being accepted.
    //  - Promotion writes outside the workspace, so it is permission-gated:
    //    the user approves each promotion.
    
    static let name = "promote_python_tool"

    private let workspace: () -> [String]

    var syntaxCheckTimeout: TimeInterval = 15   // Timeout for the host-side syntax check.

    // TODO: Unsure if will use promotion summary for memory (possible example: tool.memoryRecorder = { MempalaceMemory.shared.store($0, tags: ["python-tool"]) })
    var memoryRecorder: ((String) -> Void)?

    init(workspace: @escaping () -> [String]) {
        self.workspace = workspace
    }

    func permissionRequests(args: [String: Any]) -> [PermissionRequest] {
        // Best to always ask for permission every time (at least until fully tested)
        return [
            PermissionRequest(action: .harness)
        ]
    }

    private let toolDescription = """
        Saves a Python module from this chat's workspace into DAWSON's shared \
        python-scripts library, making it permanently importable (by module name) \
        in ALL future conversations and by all agents via \(RunPythonScript.name). Only \
        promote tools that are tested, working, general-purpose (not hardcoded to \
        this one task), and self-documenting (docstrings on the module and its \
        public functions — these become the tool's catalog entry that future \
        agents rely on). The user must approve each promotion. The file is \
        syntax-checked before being accepted; the tool catalog and shared memory \
        are updated automatically. A promoted module takes import precedence over \
        a same-named workspace module. Overwritten versions are archived, not destroyed.
        """

    private let parameterSchema: [String: Any] = [
        "type": "object",
        "required": ["source_path", "description"],
        "properties": [
            "source_path": [
                "type": "string",
                "description": "Path to the .py file in the workspace (absolute, or relative to a workspace root)"
            ],
            "tool_name": [
                "type": "string",
                "description": "Module name to publish as (a valid Python identifier, e.g. 'csv_summarizer'). Defaults to the source filename without .py"
            ],
            "description": [
                "type": "string",
                "description": "One or two sentences describing what the tool does and its entry-point functions. Becomes the tool's catalog description."
            ],
            "overwrite": [
                "type": "boolean",
                "description": "Replace an existing library module of the same name (default false). The previous version is archived."
            ]
        ]
    ]

    func openAISchema() -> [String: Any] {
        return [
            "type": "function",
            "name": PromotePythonTool.name,
            "description": toolDescription,
            "parameters": parameterSchema
        ]
    }

    func anthropicSchema() -> [String: Any] {
        return [
            "name": PromotePythonTool.name,
            "description": toolDescription,
            "input_schema": parameterSchema
        ]
    }

    func ollamaSchema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": PromotePythonTool.name,
                "description": toolDescription,
                "parameters": parameterSchema
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let sourcePathArg = args["source_path"] as? String else {
            return "Error: Missing required parameter 'source_path'"
        }
        guard let description = args["description"] as? String,
              !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Error: Missing required parameter 'description'"
        }
        let overwrite = args["overwrite"] as? Bool ?? false

        let workspaces = workspace().map(FileUtilities.canonicalFilePath)
        guard (!workspaces.isEmpty) else {
            return "Error: No workspace directories are configured for this chat."
        }

        // Resolve and validate the source
        guard let source = Self.resolveSource(sourcePathArg, workspaces: workspaces) else {
            return "Error: '\(sourcePathArg)' does not exist inside this chat's workspace. The source must be a .py file within a workspace directory."
        }
        guard (source.hasSuffix(".py")) else {
            return "Error: Only .py files can be promoted."
        }

        // Validate the destination name
        let stem = URL(fileURLWithPath: source).deletingPathExtension().lastPathComponent
        let toolName = (args["tool_name"] as? String) ?? stem
        guard Self.isValidModuleName(toolName) else {
            return "Error: '\(toolName)' is not a valid Python module name. Use letters, digits, and underscores, not starting with a digit."
        }

        let scriptsDir = ToolCatalog.scriptsDirectory
        let destination = scriptsDir.appendingPathComponent("\(toolName).py")
        let destinationExists = FileManager.default.fileExists(atPath: destination.path)

        if (destinationExists && !overwrite) {
            return "Error: A library tool named '\(toolName)' already exists. Pass overwrite: true to replace it (the old version will be archived), or choose a different tool_name."
        }

        // Syntax check (ast.parse only — parses, never executes)
        do {
            let check = try HostProcess.run(
                executable: PythonEnv.pythonExecPath,
                arguments: [
                    "-c",
                    "import ast, sys; ast.parse(open(sys.argv[1], encoding='utf-8').read(), filename=sys.argv[1])",
                    source
                ],
                environment: [
                    "PYTHONHOME": PythonEnv.pythonHome.path,
                    "PYTHONNOUSERSITE": "1",
                    "PYTHONDONTWRITEBYTECODE": "1",
                ],
                timeout: syntaxCheckTimeout
            )
            if !check.succeeded {
                let detail = check.timedOut ? "syntax check timed out" : check.stderr
                return "Error: '\(sourcePathArg)' failed the syntax check and was not promoted:\n\(detail)"
            }
        } catch {
            return "Error: Could not run syntax check: \(error)"
        }

        let stamp = ISO8601DateFormatter().string(from: Date())

        // Archive the previous version instead of destroying it
        var archivedNote = ""
        if destinationExists {
            let archiveDir = scriptsDir.appendingPathComponent(".archive")
            let fileStamp = stamp
                .replacingOccurrences(of: ":", with: "-")
            let archiveURL = archiveDir.appendingPathComponent("\(toolName)-\(fileStamp).py")
            do {
                try FileManager.default.createDirectory(at: archiveDir, withIntermediateDirectories: true)
                try FileManager.default.moveItem(at: destination, to: archiveURL)
                archivedNote = " The previous version was archived to .archive/\(archiveURL.lastPathComponent)."
            } catch {
                return "Error: Could not archive the existing '\(toolName)' before overwriting: \(error). Nothing was changed."
            }
        }

        // Write with a provenance header
        do {
            let contents = try String(contentsOfFile: source, encoding: .utf8)
            let header = """
            # ---------------------------------------------------------------
            # DAWSON promoted tool: \(toolName)
            # Promoted: \(stamp)
            # Description: \(description.replacingOccurrences(of: "\n", with: " "))
            # Origin: \(source)
            # ---------------------------------------------------------------

            """
            try FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
            try (header + contents).write(to: destination, atomically: true, encoding: .utf8)
        } catch {
            return "Error: Failed to write '\(toolName)' to the library: \(error)"
        }

        // Mechanical follow-through: catalog + shared memory
        ToolCatalog.regenerate()

        var memoryNote = ""
        if let memoryRecorder {
            let entryPoints = ToolCatalog.loadEntries()
                .first(where: { $0.module == toolName })?
                .functions.map { "\($0.name)(\($0.signature))" }
                .joined(separator: "; ") ?? "see catalog"
            memoryRecorder("""
            Python tool '\(toolName)' was added to DAWSON's shared library on \(stamp). \
            Purpose: \(description) \
            Entry points: \(entryPoints). \
            Usable by any agent via \(RunPythonScript.name) (module '\(toolName)'); \
            discoverable via \(ListPythonTools.name).
            """)
            memoryNote = " Recorded in shared memory."
        }

        return """
        Promoted '\(toolName)' to DAWSON's shared tool library. It is now importable \
        as module '\(toolName)' via \(RunPythonScript.name) in this and all future \
        conversations, for all agents, and appears in \(ListPythonTools.name). \
        The tool catalog was updated.\(memoryNote)\(archivedNote)
        """
    }
}

extension PromotePythonTool {
    
    private static func resolveSource(_ raw: String, workspaces: [String]) -> String? {
        // Resolves an absolute or workspace-relative path to an existing file inside workspace roots.
        var candidates: [String] = []
        if raw.hasPrefix("/") {
            candidates.append(raw)
        } else {
            candidates.append(contentsOf: workspaces.map { "\($0)/\(raw)" })
        }

        for candidate in candidates {
            guard FileManager.default.fileExists(atPath: candidate),
                  FileUtilities.inSessionDirectories(path: candidate, directories: workspaces) else {
                continue
            }
            // Return the canonical path so the provenance header / dedup key is stable.
            return FileUtilities.canonicalFilePath(candidate)
        }
        return nil
    }

    private static func isValidModuleName(_ name: String) -> Bool {
        name.range(of: "^[A-Za-z_][A-Za-z0-9_]{0,63}$", options: .regularExpression) != nil
    }
}

//
//  ToolCatalog.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/21/26.
//

//  Maintains python-scripts/catalog.json: a machine-readable index of the
//  shared tool library (module names, descriptions, public entry points with
//  signatures and doc lines). Regenerated after every promotion; read by the
//  list_python_tools agent tool and by Loader.loadPythonToolSummaries().
//
//  Generation uses the bundled interpreter with ast.parse only — modules are
//  parsed, never imported or executed, so cataloging is safe regardless of
//  what the files contain.
//

import Foundation

final class ToolCatalog {

    private init() {}

    static var scriptsDirectory: URL {
        DAWSON.root.appendingPathComponent("python-scripts")
    }

    static var catalogURL: URL {
        scriptsDirectory.appendingPathComponent("catalog.json")
    }

    @discardableResult
    static func regenerate(timeout: TimeInterval = 30) -> Bool {
        // Rescans python-scripts and rewrites catalog.json.
        // Returns true on success. Safe to call from any thread.
        
        try? FileManager.default.createDirectory(at: scriptsDirectory, withIntermediateDirectories: true)
        do {
            let result = try HostProcess.run(
                executable: PythonEnv.pythonExecPath,
                arguments: ["-c", generatorSource, scriptsDirectory.path],
                environment: [
                    "PYTHONHOME": PythonEnv.pythonHome.path,
                    "PYTHONNOUSERSITE": "1",
                    "PYTHONDONTWRITEBYTECODE": "1",
                ],
                timeout: timeout
            )
            return result.succeeded
        } catch {
            return false
        }
    }

    static func loadEntries() -> [ToolEntry] {
        // Loads catalog entries, regenerating the file if it's missing.
        
        if (!FileManager.default.fileExists(atPath: catalogURL.path)) {
            regenerate()
        }
        guard let data = try? Data(contentsOf: catalogURL),
              let catalog = try? JSONDecoder().decode(Catalog.self, from: data) else {
            return []
        }
        return catalog.tools
    }

    // Full, model-readable listing used by the ListPythonTools tool.
    static func formattedList() -> String {
        let entries = loadEntries()
        guard (!entries.isEmpty) else {
            return "The shared Python tool library is currently empty. Write tools in the workspace and promote proven ones with promote_python_tool."
        }
        let body = entries.map { tool in
            let functions = tool.functions.map { fn in
                let doc = fn.doc.isEmpty ? "" : " — \(fn.doc)"
                return "    - \(fn.name)(\(fn.signature))\(doc)"
            }.joined(separator: "\n")
            let desc = tool.description.isEmpty ? "(no description)" : tool.description
            return "• \(tool.module) — \(desc)\n\(functions.isEmpty ? "    (no public functions)" : functions)"
        }.joined(separator: "\n\n")

        return """
        Shared Python tool library (\(entries.count) tool\(entries.count == 1 ? "" : "s")). \
        Call any of these via run_python_script with the module and function name; \
        arguments are passed as keywords.

        \(body)
        """
    }

    static func promptSummary() -> String {
        // Compact one-line-per-tool summary for injection into system prompts via Loader
        let entries = loadEntries()
        guard (!entries.isEmpty) else { return "" }
        return entries.map { tool in
            let fns = tool.functions.map(\.name).joined(separator: ", ")
            return "- \(tool.module): \(tool.description.isEmpty ? "(no description)" : tool.description) [functions: \(fns)]"
        }.joined(separator: "\n")
    }
}

extension ToolCatalog {
    
    struct FunctionEntry: Codable {
        let name: String
        let signature: String
        let doc: String
    }

    struct ToolEntry: Codable {
        let module: String
        let description: String
        let functions: [FunctionEntry]
    }

    private struct Catalog: Codable {
        let generated: String
        let tools: [ToolEntry]
    }
}

extension ToolCatalog {
    // ast-based scanner: for each top-level .py file, extracts the
    // description (provenance "# Description:" header wins, module
    // docstring as fallback) and every public top-level function with
    // its signature and first docstring line. Unparseable files are
    // skipped. Writes catalog.json into the scanned directory.
    private static let generatorSource =
    """
    import ast, json, os, sys, datetime

    root = sys.argv[1]
    tools = []
    for fname in sorted(os.listdir(root)):
        if not fname.endswith(".py"):
            continue
        path = os.path.join(root, fname)
        if not os.path.isfile(path):
            continue
        try:
            with open(path, encoding="utf-8") as f:
                src = f.read()
            tree = ast.parse(src)
        except Exception:
            continue

        desc = (ast.get_docstring(tree) or "").split("\\n")[0]
        for line in src.splitlines()[:12]:
            if line.startswith("# Description:"):
                desc = line[len("# Description:"):].strip()
                break

        functions = []
        for node in tree.body:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and not node.name.startswith("_"):
                try:
                    sig = ast.unparse(node.args)
                except Exception:
                    sig = ""
                doc = (ast.get_docstring(node) or "").split("\\n")[0]
                functions.append({"name": node.name, "signature": sig, "doc": doc})

        tools.append({"module": fname[:-3], "description": desc, "functions": functions})

    catalog = {
        "generated": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "tools": tools,
    }
    with open(os.path.join(root, "catalog.json"), "w", encoding="utf-8") as f:
        json.dump(catalog, f, indent=2)
    """
}

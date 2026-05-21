//
//  RunPythonScript.swift
//
//
//  Created by Ethan Brown on 4/30/26.
//

import Foundation
import PythonKit

class RunPythonScript: ChatSessionAware {
    let name = "run_python_script"
    private var session: ChatSessionInfo?

    func setSession(_ session: ChatSessionInfo) {
        self.session = session
    }
    
    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Executes a Python function from a specified module using PythonHandler and returns the result. This does not execute modules/functions using the host computer's Python, it utilizes the Python venv environment in the DAWSON root directory.",
                "parameters": [
                    "type": "object",
                    "required": ["module", "function"],
                    "properties": [
                        "module": [
                            "type": "string",
                            "description": "The Python module name to import (e.g. 'mymodule')"
                        ],
                        "function": [
                            "type": "string",
                            "description": "The function name inside the module to execute"
                        ],
                        "args": [
                            "type": "object",
                            "description": "Dictionary of arguments passed to the Python function",
                            "additionalProperties": true
                        ]
                    ]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) async -> String {
        guard let module = args["module"] as? String,
              let function = args["function"] as? String else {
            return "Error: Missing required parameters 'module' or 'function'"
        }
        let rawArgs = args["args"] as? [String: Any] ?? [:]

        guard let session = session else {
            return "Invalid chat session. Developer error."
        }
        do {
            try ToolPermissionGuard.guardAll(session: session)
        } catch {
            return String(describing: error)
        }
        
        do {
            let result = try PythonHandler.shared.call(moduleName: module, functionName: function, args: rawArgs)
            let convResult = PythonHandler.shared.fromPython(result)
            
            return String(describing: convResult)
        } catch {
            return "Python execution error: \(error)"
        }
    }
}

//
//  PythonUtilities.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/21/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import PythonKit

class PythonUtilities {
    
    static func convertDictionary(_ dict: [String: Any]) throws -> [String: PythonObject] {
        var converted: [String: PythonObject] = [:]
        for (key, value) in dict {
            converted[key] = try toPython(value)
        }

        return converted
    }

    static func toPython(_ value: Any) throws -> PythonObject {
        switch value {
        case let v as String:        return PythonObject(v)
        case let v as Int:           return PythonObject(v)
        case let v as Double:        return PythonObject(v)
        case let v as Float:         return PythonObject(Double(v))
        case let v as Bool:          return PythonObject(v)
        case let v as [String: Any]: return PythonObject(try convertDictionary(v))
        case let v as [Any]:         return PythonObject(try v.map { try toPython($0) })
        case let v as [String]:      return PythonObject(v)
        case let v as [Int]:         return PythonObject(v)
        case let v as [Double]:      return PythonObject(v)
        case is NSNull:              return Python.None
        default:
            throw PythonError.invalidArgumentType("Unsupported type for \(type(of: value))")
        }
    }
    
    static func fromPython(_ obj: PythonObject) -> Any {
        if let dict = Dictionary<String, PythonObject>(obj) {
            var result: [String: Any] = [:]
            for (key, value) in dict {
                result[key] = fromPython(value)
            }

            return result
        }

        if let array = Array<PythonObject>(obj) {
            return array.map { fromPython($0) }
        }

        if let bool = Bool(obj) { return bool }
        if let int = Int(obj) { return int }
        if let double = Double(obj) { return double }
        if let string = String(obj) { return string }

        if (String(describing: obj) == "None") {
            return NSNull()
        }

        return String(describing: obj)
    }
    
    static func memoryPrelude(_ megabytes: Int) -> String {
        // RLIMIT_AS cap. Enforced on Linux; best-effort on macOS.
        
        return """
        try:
            import resource
            _dawson_lim = \(megabytes) * 1024 * 1024
            resource.setrlimit(resource.RLIMIT_AS, (_dawson_lim, _dawson_lim))
        except Exception:
            pass
        """
    }
    
    static func moduleBootstrap(memoryLimitMB: Int) -> String {
        // Reads {"module","function","args"} as JSON on stdin, imports, and calls
        // fn(**args), prints a single JSON object as the LAST stdout line.
        // Non-JSON-serializable results fall back to repr().
        
        return """
        \(memoryPrelude(memoryLimitMB))
        import sys, json, importlib, traceback

        def main():
            try:
                payload = json.load(sys.stdin)
                mod = importlib.import_module(payload["module"])
                fn = getattr(mod, payload["function"], None)
                if fn is None or not callable(fn):
                    raise AttributeError(
                        "function %r not found in module %r"
                        % (payload["function"], payload["module"])
                    )
                result = fn(**(payload.get("args") or {}))
                try:
                    print(json.dumps({"ok": True, "result": result}))
                except TypeError:
                    print(json.dumps({"ok": True, "result": repr(result)}))
            except BaseException:
                print(json.dumps({"ok": False, "error": traceback.format_exc()}))
                sys.exit(1)

        main()
        """
    }
    
    static func scriptRunner(memoryLimitMB: Int) -> String {
        // Executes sys.argv[1] as __main__ with the remaining args as its argv.
        return """
        \(memoryPrelude(memoryLimitMB))
        import sys, runpy
        _dawson_path = sys.argv[1]
        sys.argv = sys.argv[1:]
        runpy.run_path(_dawson_path, run_name="__main__")
        """
    }
}

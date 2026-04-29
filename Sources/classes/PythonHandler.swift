//
//  PythonHandler.swift
//
//
//  Created by Ethan Brown on 4/26/26.
//

import Foundation


import PythonKit

class PythonHandler {
    static let shared = PythonHandler()
    
    private var sys: PythonObject?
    
    private init() {}
    
    private func ensurePython() {
        if (sys != nil) { return }

        let sysModule = Python.import("sys")

        let projectRoot = FileManager.default.currentDirectoryPath

        sysModule.path.append(projectRoot + "/python")
        sysModule.path.append(projectRoot + "/python/venv/lib/python3.11/site-packages")

        sys = sysModule
    }
    
    func call(module: String, function: String, args: [String: Any] = [:]) -> PythonObject {
        ensurePython()
        
        let pyModule = Python.import(module)
        let pyArgs = convertToPython(args)
        let fn = pyModule.__getattribute__(function)

        return fn(pyArgs)
    }
    
    func convertToPython(_ dict: [String: Any]) -> PythonObject {
        var pyDict = Python.dict()

        for (key, value) in dict {
            pyDict[key] = toPython(value)
        }

        return pyDict
    }

    func toPython(_ value: Any) -> PythonObject {
        switch value {
        case let v as String:
            return Python.str(v)
        case let v as Int:
            return Python.int(v)
        case let v as Double:
            return Python.float(v)
        case let v as Bool:
            return Python.bool(v)
        case let v as [String: Any]:
            return convertToPython(v)
        case let v as [Any]:
            return Python.list(v.map { toPython($0) })
        default:
            return Python.str("\(value)")
        }
    }
    
    func fromPython(_ obj: PythonObject) -> Any {
        if let dict = Dictionary<String, PythonObject>(obj) {
            var result: [String: Any] = [:]
            for (k, v) in dict {
                result[k] = fromPython(v)
            }
            return result
        }

        if let array = [PythonObject](obj) {
            return array.map { fromPython($0) }
        }

        if let string = String(obj) { return string }
        if let int = Int(obj) { return int }
        if let double = Double(obj) { return double }
        if let bool = Bool(obj) { return bool }

        return String(describing: obj)
    }
}

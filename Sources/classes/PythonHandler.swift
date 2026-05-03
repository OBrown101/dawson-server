//
//  PythonHandler.swift
//
//
//  Created by Ethan Brown on 4/26/26.
//

import Foundation


import PythonKit

enum PythonHandlerError: Error {
    case moduleNotFound(String)
    case functionNotFound(String)
    case invalidArgumentType(String)
    case pythonExecutionFailed(String)
}

class PythonHandler {
    static let shared = PythonHandler()
    
    private var sys: PythonObject?
    private let queue = DispatchQueue(label: "python.handler.queue")
    
    private init() {}
    
    private func ensurePython() throws {
        if (sys != nil) { return }
        
        let sysModule = try Python.attemptImport("sys")
        let projectRoot = FileManager.default.currentDirectoryPath
        
        let pythonPaths = [
            "\(projectRoot)/python",
            "\(projectRoot)/python/venv/lib/python3.11/site-packages"
        ]
        for path in pythonPaths {
            sysModule.path.append(path)
        }
        
        sys = sysModule
    }
    
    func call(moduleName: String, functionName: String, args: [String: Any] = [:]) throws -> PythonObject {
        return try queue.sync {
            try ensurePython()
            
            let module: PythonObject
            do {
                module = try Python.attemptImport(moduleName)
            } catch {
                throw PythonHandlerError.moduleNotFound(moduleName)
            }
            
            let args = try toPython(args)
            
            guard let function = module.checking[dynamicMember: functionName] else {
                throw PythonHandlerError.functionNotFound(functionName)
            }
            let result = try function.throwing.dynamicallyCall(withArguments: args)
            
            // Detect Python-side exceptions
            let builtins = try Python.attemptImport("builtins")
            if Bool(builtins.isinstance(result, builtins.BaseException)) == true {
                throw PythonHandlerError.pythonExecutionFailed(String(describing: result))
            }
            
            return result
        }
    }
    
    private func convertDictionary(_ dict: [String: Any]) throws -> [String: PythonObject] {
        var converted: [String: PythonObject] = [:]
        for (key, value) in dict {
            converted[key] = try toPython(value)
        }

        return converted
    }

    private func toPython(_ value: Any) throws -> PythonObject {
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
            throw PythonHandlerError.invalidArgumentType("Unsupported type for \(type(of: value))")
        }
    }
    
    func fromPython(_ obj: PythonObject) -> Any {
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
}

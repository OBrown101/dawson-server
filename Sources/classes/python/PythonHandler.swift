//
//  PythonHandler.swift
//
//
//  Created by Ethan Brown on 4/26/26.
//

import Foundation


import PythonKit

enum PythonError: Error {
    case moduleNotFound(String)
    case functionNotFound(String)
    case invalidArgumentType(String)
    case pythonExecutionFailed(String)
    case invalidScriptPath(String)
    case processFailed(String)
}

struct PythonProcess {
    let process: Process
    let pid: Int32
}

class PythonHandler: @unchecked Sendable {
    static let shared = PythonHandler()
    
    private var sys: PythonObject?
    private let queue = DispatchQueue(label: "python.handler.queue")
    
    private init() {}
    
    private func ensurePython() throws {
        if (sys != nil) { return }
        
        let scriptsPath = DAWSON.root.appendingPathComponent("python-scripts")
        
        let sysModule = try Python.attemptImport("sys")
        sysModule.path.insert(0, PythonEnv.pythonPackagesPath)
        sysModule.path.insert(0, PythonEnv.pythonHome.path)
        sysModule.path.insert(0, scriptsPath.path)
        
        sys = sysModule
    }
    
    func call(moduleName: String, functionName: String, args: [String: Any] = [:]) throws -> PythonObject {
        return try queue.sync {
            try ensurePython()
            
            let module: PythonObject
            do {
                module = try Python.attemptImport(moduleName)
            } catch {
                throw PythonError.moduleNotFound(moduleName)
            }
            
            let args = try toPython(args)
            
            guard let function = module.checking[dynamicMember: functionName] else {
                throw PythonError.functionNotFound(functionName)
            }
            let result = try function.throwing.dynamicallyCall(withArguments: args)
            
            // Detect Python-side exceptions
            let builtins = try Python.attemptImport("builtins")
            if Bool(builtins.isinstance(result, builtins.BaseException)) == true {
                throw PythonError.pythonExecutionFailed(String(describing: result))
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
            throw PythonError.invalidArgumentType("Unsupported type for \(type(of: value))")
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

extension PythonHandler {
    func startPythonProcess(
        scriptPath: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        inputPipe: Pipe,
        outputPipe: Pipe,
        errorPipe: Pipe
    ) throws -> PythonProcess {
        try ensurePython()
        
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            throw PythonError.invalidScriptPath(scriptPath)
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: PythonEnv.pythonExecPath)
        process.arguments = [scriptPath] + arguments

        var env = ProcessInfo.processInfo.environment
        env["PYTHONHOME"] = PythonEnv.pythonHome.path
        env["PYTHONPATH"] = PythonEnv.pythonPackagesPath
        env["PYTHONSAFEPATH"] = "1"

        if let extraEnv = environment {
            for (k, v) in extraEnv {
                env[k] = v
            }
        }

        process.environment = env
        process.standardInput = inputPipe.fileHandleForWriting
        process.standardOutput = outputPipe.fileHandleForReading
        process.standardError = errorPipe.fileHandleForWriting

        do {
            try process.run()
        } catch {
            throw PythonError.processFailed(error.localizedDescription)
        }

        return PythonProcess(
            process: process,
            pid: process.processIdentifier
        )
    }

    func isRunning(_ handle: PythonProcess) -> Bool {
        return handle.process.isRunning
    }

    func stop(_ handle: PythonProcess) {
        handle.process.terminate()
    }
}

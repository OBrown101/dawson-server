//
//  PythonEnv.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/10/26.
//

import Foundation

final class PythonEnv: @unchecked Sendable {
    static let pythonVersion = "3.11"
    static let pythonVersionBasic = pythonVersion.replacingOccurrences(of: ".", with: "")
    
    #if os(macOS)
    static let pythonHome = DAWSON.root
        .appendingPathComponent("python-macos")
    static let pythonLibPath = pythonHome
        .appendingPathComponent("lib")
        .appendingPathComponent("libpython\(pythonVersion).dylib")
        .path
    static let pythonPackagesPath = pythonHome
        .appendingPathComponent("lib")
        .appendingPathComponent("python\(pythonVersion)")
        .appendingPathComponent("site-packages")
        .path
    static let pythonExecPath = pythonHome
        .appendingPathComponent("bin")
        .appendingPathComponent("python3")
        .path
    #elseif os(Windows)
    static let pythonHome = URL(fileURLWithPath: DAWSON.root).appendingPathComponent("python-windows")
    static let pythonLibPath = pythonHome
        .appendingPathComponent("python\(pythonVersionBasic).dll")
        .path
    static let pythonPackagesPath = pythonHome
        .appendingPathComponent("Lib")
        .appendingPathComponent("site-packages")
        .path
    static let pythonExecPath = pythonHome
        .appendingPathComponent("python.exe")
        .path
    #endif
    
    static func setEnv() {
        // IMPORTANT: This function must be called before PythonKit is imported.
        
//        print("🐍 Python Environment Setup")
//        print("PYTHON_VERSION:", pythonVersion)
//        print("PYTHON_VERSION_BASIC:", pythonVersionBasic)
//        print("PYTHONHOME:", pythonHome.path)
//        print("PYTHON_LIBRARY:", pythonLibPath)
//        print("PYTHONPATH:", pythonPackagesPath)
//        print("PYTHON_EXEC:", pythonExecPath)
        
        #if os(macOS)
        setenv("PYTHON_LIBRARY", pythonLibPath, 1)
        setenv("PYTHONHOME", pythonHome.path, 1)
        setenv("PYTHONPATH", pythonPackagesPath, 1)
        setenv("PYTHONSAFEPATH", "1", 1)
        #elseif os(Windows)
        _putenv_s("PYTHON_LIBRARY", pythonLibPath)
        _putenv_s("PYTHONHOME", pythonHome.path)
        _putenv_s("PYTHONPATH", pythonPackagesPath)
        _putenv_s("PYTHONSAFEPATH", "1")
        #endif
    }
}

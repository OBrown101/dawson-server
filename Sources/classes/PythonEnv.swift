//
//  PythonEnv.swift
//  DAWSON
//
//  Created by Ethan Brown on 5/10/26.
//

import Foundation

final class PythonEnv: @unchecked Sendable {
    
    static private let projectRoot = FileManager.default.currentDirectoryPath
    static let pythonHomePath = "\(projectRoot)/python/python3/3.11"
    static let pythonLibPath = "\(pythonHomePath)/lib/libpython3.11.dylib"
    static let pythonPackagesPath = "\(pythonHomePath)/lib/python3.11/site-packages"
    static let pythonExecPath = "\(pythonHomePath)/bin/python3"
    
    static func setEnv() {
        setenv("PYTHON_LIBRARY", pythonLibPath, 1)
        setenv("PYTHONHOME", pythonHomePath, 1)
        setenv("PYTHONPATH", pythonPackagesPath, 1)
        setenv("PYTHONSAFEPATH", "1", 1)
    }
}

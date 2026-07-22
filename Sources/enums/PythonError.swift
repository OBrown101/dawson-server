//
//  PythonError.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/21/26.
//

enum PythonError: Error {
    case moduleNotFound(String)
    case functionNotFound(String)
    case invalidArgumentType(String)
    case pythonExecutionFailed(String)
    case invalidScriptPath(String)
    case processFailed(String)
}

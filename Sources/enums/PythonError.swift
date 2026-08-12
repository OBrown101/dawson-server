//
//  PythonError.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/21/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

enum PythonError: Error {
    case moduleNotFound(String)
    case functionNotFound(String)
    case invalidArgumentType(String)
    case pythonExecutionFailed(String)
    case invalidScriptPath(String)
    case processFailed(String)
}

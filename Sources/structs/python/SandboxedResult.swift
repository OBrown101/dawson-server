//
//  SandboxedResult.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/21/26.
//

struct SandboxedResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let timedOut: Bool
}

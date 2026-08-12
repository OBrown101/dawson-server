//
//  SandboxedResult.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/21/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

struct SandboxedResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let timedOut: Bool
}

//
//  HostProcessResult.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/21/26.
//

import Foundation

struct HostProcessResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let timedOut: Bool
    var succeeded: Bool { (!timedOut && (exitCode == 0)) }
}

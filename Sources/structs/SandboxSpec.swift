//
//  SandboxSpec.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/21/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

struct SandboxSpec: Sendable {
    var writableDirectories: [String]       // Directories the script may read/write (agent's workspace).
    var readOnlyDirectories: [String] = []  // Read-only directories beyond the Python runtime (e.g. DAWSON.root/python-scripts).
    var executableDirectories: [String] = [] // Read + exec directories beyond the platform baseline (e.g. host developer toolchain).
    var scratchPath: String? = nil          // Agent persistent scratch pad (writable, added to PYTHONPATH, exposed to script as os.environ["DAWSON_SCRATCH"]).
    var allowNetwork: Bool = false          // Outbound network access. Default: none.
    var timeout: TimeInterval = 60          // Wall-clock limit (process killed when expires)
    var memoryLimitMB: Int = 2048           // RLIMIT_AS address-space cap (enforced Linux, best-effort macOS)
}

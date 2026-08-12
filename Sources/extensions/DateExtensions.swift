//
//  DateExtensions.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/22/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

extension Date {
    var epochMillis: Int64 {
        Int64(self.timeIntervalSince1970 * 1000)
    }
}

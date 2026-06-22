//
//  DateExtensions.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/22/26.
//

import Foundation

extension Date {
    var epochMillis: Int64 {
        Int64(self.timeIntervalSince1970 * 1000)
    }
}

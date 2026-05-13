//
//  DateHandler.swift
//  
//
//  Created by Ethan Brown on 3/24/26.
//

import Foundation

class DateHandler: @unchecked Sendable {
    static let shared = DateHandler()
    let formatter = DateFormatter()
    let iso8601Formatter = ISO8601DateFormatter()
    
    private init() {
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss 'UTC'" // e.g., 2026-03-23 05:03:37 UTC
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }
    
    func getNow() -> String {
        return formatter.string(from: Date.now)
    }
    
    func fromISO8601ToUTC(_ string: String) -> Date? {
        iso8601Formatter.date(from: string)
    }
}

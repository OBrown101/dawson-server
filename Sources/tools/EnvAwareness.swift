//
//  EnvAwareness.swift
//
//
//  Created by Ethan Brown on 4/28/26.
//

import Foundation

class EnvAwareness: Tool {
    let name = "environmental_awareness"

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Provides the agent with current situational/environmental awareness data such as time, date, day of week, timezone, operating system, user, and system uptime.",
                "parameters": [
                    "type": "object",
                    "required": [],
                    "properties": [:]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) -> String {
        // Current date & time
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        formatter.timeZone = TimeZone.current
        let dateString = formatter.string(from: now)

        // Time zone
        let tzName = TimeZone.current.identifier

        // Day of week
        formatter.dateFormat = "EEEE"
        let dayOfWeek = formatter.string(from: now)

        // Operating system
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString

        // Current user
        let user = NSUserName()

        // System uptime (seconds)
        let uptimeSeconds = ProcessInfo.processInfo.systemUptime
        let uptimeFormatter = DateComponentsFormatter()
        uptimeFormatter.allowedUnits = [.day, .hour, .minute, .second]
        uptimeFormatter.unitsStyle = .full
        let uptimeString = uptimeFormatter.string(from: uptimeSeconds) ?? "unknown"

        // Assemble response
        let info = """
        Current date & time: \(dateString)
        Time zone: \(tzName)
        Day of week: \(dayOfWeek)
        Operating system: \(osVersion)
        Current user: \(user)
        System uptime: \(uptimeString)
        """

        return info
    }
}

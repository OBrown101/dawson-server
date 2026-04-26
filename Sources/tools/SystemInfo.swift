//
//  SystemInfo.swift
//  
//
//  Created by Ethan Brown on 3/23/26.
//

import Foundation

class SystemInfo: Tool {
    let name = "system_info"

    func schema() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": "Returns detailed system information (OS, CPU, memory, disk, network, uptime).",
                "parameters": [
                    "type": "object",
                    "required": [],
                    "properties": [:]
                ]
            ]
        ]
    }

    func execute(args: [String: Any]) -> String {
        var info: [String] = []

        let processInfo = ProcessInfo.processInfo

        // OS Info
        let osVersion = processInfo.operatingSystemVersion
        let osName: String
        #if os(macOS)
        osName = "macOS"
        #elseif os(Linux)
        osName = "Linux"
        #elseif os(Windows)
        osName = "Windows"
        #else
        osName = "Unknown"
        #endif
        info.append("OS: \(osName) \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)")

        // Hostname & User
        info.append("Hostname: \(processInfo.hostName)")
        info.append("User: \(NSUserName())")

        // CPU
        info.append("CPU Cores (logical): \(processInfo.processorCount)")
        info.append("CPU Cores (physical): \(processInfo.activeProcessorCount)")

        // Memory
        let physicalMemoryMB = processInfo.physicalMemory / 1024 / 1024
        info.append("Physical Memory: \(physicalMemoryMB) MB")

        // Uptime
        let uptimeSeconds = Int(processInfo.systemUptime)
        let hours = uptimeSeconds / 3600
        let minutes = (uptimeSeconds % 3600) / 60
        let seconds = uptimeSeconds % 60
        info.append("Uptime: \(hours)h \(minutes)m \(seconds)s")

        // Disk Info (cross-platform approximation)
        let fileManager = FileManager.default
        do {
            let attrs = try fileManager.attributesOfFileSystem(forPath: "/")
            if let totalSpace = attrs[.systemSize] as? NSNumber,
               let freeSpace = attrs[.systemFreeSize] as? NSNumber {
                info.append("Disk Total: \(totalSpace.int64Value / 1024 / 1024) MB")
                info.append("Disk Free: \(freeSpace.int64Value / 1024 / 1024) MB")
            }
        } catch {
            info.append("Disk info: unavailable")
        }

        // Network Interfaces
        #if os(macOS) || os(Linux)
        let networkInterfaces = getifaddrsList()
        info.append("Network Interfaces: \(networkInterfaces.joined(separator: ", "))")
        #else
        info.append("Network Interfaces: unavailable")
        #endif

        return info.joined(separator: "\n")
    }

    #if os(macOS) || os(Linux)
    private func getifaddrsList() -> [String] {
        var interfaceNames: [String] = []
        var ifaddrPointer: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddrPointer) == 0, let firstAddr = ifaddrPointer {
            var ptr = firstAddr
            while ptr.pointee.ifa_next != nil {
                if let name = ptr.pointee.ifa_name {
                    let interface = String(cString: name)
                    if !interfaceNames.contains(interface) {
                        interfaceNames.append(interface)
                    }
                }
                ptr = ptr.pointee.ifa_next!
            }
            freeifaddrs(ifaddrPointer)
        }
        return interfaceNames
    }
    #endif
}

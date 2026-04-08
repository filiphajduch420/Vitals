import Foundation

// MARK: - CPU Metrics

struct CPUMetrics: Codable, Sendable {
    let totalUsage: Double      // 0.0 – 1.0
    let userUsage: Double
    let systemUsage: Double
    let idleUsage: Double
    let activeCores: Int
    let totalCores: Int

    static let empty = CPUMetrics(totalUsage: 0, userUsage: 0, systemUsage: 0, idleUsage: 0, activeCores: 0, totalCores: 0)
}

// MARK: - Memory Metrics

enum MemoryPressureLevel: String, Codable, Sendable {
    case nominal, warning, critical
}

struct MemoryMetrics: Codable, Sendable {
    let total: UInt64
    let used: UInt64
    let free: UInt64
    let active: UInt64
    let inactive: UInt64
    let wired: UInt64
    let compressed: UInt64
    let pressure: MemoryPressureLevel

    var usageRatio: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }

    static let empty = MemoryMetrics(
        total: 0, used: 0, free: 0, active: 0,
        inactive: 0, wired: 0, compressed: 0, pressure: .nominal
    )
}

// MARK: - Network Metrics

struct NetworkMetrics: Codable, Sendable {
    let uploadSpeed: UInt64
    let downloadSpeed: UInt64
    let totalUploaded: UInt64
    let totalDownloaded: UInt64

    static let empty = NetworkMetrics(
        uploadSpeed: 0, downloadSpeed: 0, totalUploaded: 0, totalDownloaded: 0
    )
}

// MARK: - Battery Metrics

struct BatteryMetrics: Codable, Sendable {
    let percentage: Int
    let isCharging: Bool
    let isPluggedIn: Bool
    let timeRemaining: TimeInterval?
    let cycleCount: Int?

    static let empty = BatteryMetrics(
        percentage: 0, isCharging: false, isPluggedIn: false,
        timeRemaining: nil, cycleCount: nil
    )
}

// MARK: - Disk Metrics

struct DiskMetrics: Codable, Sendable {
    let totalSpace: UInt64
    let usedSpace: UInt64
    let freeSpace: UInt64
    let readSpeed: UInt64       // bytes/sec
    let writeSpeed: UInt64      // bytes/sec

    var usageRatio: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace)
    }

    static let empty = DiskMetrics(totalSpace: 0, usedSpace: 0, freeSpace: 0, readSpeed: 0, writeSpeed: 0)
}

// MARK: - Thermal Metrics

struct ThermalMetrics: Codable, Sendable {
    let stateLabel: String
    let level: Double
    let cpuTemperature: Double?
    let gpuTemperature: Double?
    let fanRPM: Int?
    let batteryTemperature: Double?
    let ssdTemperature: Double?
    let systemPower: Double?        // watts (total system)

    static let empty = ThermalMetrics(
        stateLabel: "Normal", level: 0.1,
        cpuTemperature: nil, gpuTemperature: nil, fanRPM: nil,
        batteryTemperature: nil, ssdTemperature: nil, systemPower: nil
    )
}

// MARK: - System Info Metrics

struct SystemInfoMetrics: Codable, Sendable {
    let hostname: String
    let username: String
    let osVersion: String
    let modelName: String
    let uptime: TimeInterval        // seconds since boot

    var formattedUptime: String {
        let total = Int(uptime)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let mins = (total % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h \(mins)m" }
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }

    static let empty = SystemInfoMetrics(hostname: "", username: "", osVersion: "", modelName: "", uptime: 0)
}

// MARK: - WiFi Metrics

struct WiFiMetrics: Codable, Sendable {
    let ssid: String?
    let rssi: Int?              // dBm (e.g. -45)
    let noise: Int?             // dBm
    let txRate: Int?            // Mbps
    let channel: String?

    var signalQuality: Double {
        guard let rssi else { return 0 }
        // Map -100..-30 dBm to 0..1
        return min(max(Double(rssi + 100) / 70.0, 0), 1)
    }

    static let empty = WiFiMetrics(ssid: nil, rssi: nil, noise: nil, txRate: nil, channel: nil)
}

// MARK: - Aggregated System Metrics

struct SystemMetrics: Codable, Sendable {
    let timestamp: Date
    var cpu: CPUMetrics
    var memory: MemoryMetrics
    var network: NetworkMetrics
    var battery: BatteryMetrics?
    var disk: DiskMetrics
    var thermal: ThermalMetrics
    var wifi: WiFiMetrics
    var systemInfo: SystemInfoMetrics
    var uptime: TimeInterval        // kept for backward compat

    static let empty = SystemMetrics(
        timestamp: .now,
        cpu: .empty,
        memory: .empty,
        network: .empty,
        battery: nil,
        disk: .empty,
        thermal: .empty,
        wifi: .empty,
        systemInfo: .empty,
        uptime: 0
    )
}

// MARK: - Metric Type

enum MetricType: String, CaseIterable, Codable, Sendable, Identifiable {
    case cpu, memory, network, battery, disk

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cpu:     return "CPU"
        case .memory:  return "Memory"
        case .network: return "Network"
        case .battery: return "Battery"
        case .disk:    return "Disk"
        }
    }

    var sfSymbol: String {
        switch self {
        case .cpu:     return "cpu.fill"
        case .memory:  return "memorychip.fill"
        case .network: return "network"
        case .battery: return "battery.75percent"
        case .disk:    return "internaldrive.fill"
        }
    }
}

// MARK: - Popover Section (for drag & drop ordering)

enum PopoverSection: String, CaseIterable, Codable, Sendable, Identifiable {
    case cpu, memory, network, battery, disk, wifi, system

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system:  return "System"
        case .cpu:     return "CPU"
        case .memory:  return "Memory"
        case .network: return "Network"
        case .battery: return "Battery"
        case .disk:    return "Disk"
        case .wifi:    return "WiFi"
        }
    }
}

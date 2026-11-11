import Foundation

/// Fixed, realistic readings for the promo screenshots (`--promo`), so every
/// render shows the same numbers. Only uses `Shared/` types: the widget
/// renderer in `tools/` compiles this file too, so the popover and the
/// widgets show the same Mac.
enum PromoDemo {
    private static let gb: UInt64 = 1024 * 1024 * 1024
    private static let mb: UInt64 = 1024 * 1024

    /// A fixed "now" so relative values (uptime, history timestamps) never drift.
    static let now = Date(timeIntervalSinceReferenceDate: 784_368_060)
    static let uptime: TimeInterval = 3 * 86_400 + 4 * 3_600 + 12 * 60
    static var bootDate: Date { now.addingTimeInterval(-uptime) }

    static let osVersion = "macOS 26.1.0"
    static let modelName = "Mac16,7"

    static let metrics = SystemMetrics(
        timestamp: now,
        cpu: CPUMetrics(totalUsage: 0.23, userUsage: 0.15, systemUsage: 0.08, idleUsage: 0.77,
                        activeCores: 12, totalCores: 12),
        memory: MemoryMetrics(total: 24 * gb, used: 13_900 * mb, free: 10_676 * mb, active: 7_600 * mb,
                              inactive: 2_150 * mb, wired: 3_200 * mb, compressed: 1_950 * mb,
                              pressure: .nominal),
        network: NetworkMetrics(uploadSpeed: 186 * 1024, downloadSpeed: 2_520 * 1024,
                                totalUploaded: 2_380 * mb, totalDownloaded: 18_600 * mb),
        battery: BatteryMetrics(percentage: 86, isCharging: false, isPluggedIn: false,
                                timeRemaining: 6 * 3_600 + 42 * 60, cycleCount: 142,
                                maxCapacity: 6_489, designCapacity: 6_900),
        disk: DiskMetrics(totalSpace: 994_662_584_320, usedSpace: 612_400_000_000,
                          freeSpace: 382_262_584_320, readSpeed: 0, writeSpeed: 1_150 * 1024),
        thermal: ThermalMetrics(stateLabel: "Normal", level: 0.1, cpuTemperature: 52, gpuTemperature: 47,
                                fanRPM: 1_840, batteryTemperature: 31.4, ssdTemperature: 38,
                                systemPower: 14.6),
        wifi: WiFiMetrics(ssid: "Studio 5G", rssi: -52, noise: -92, txRate: 1_201, channel: "149",
                          localIP: "192.168.1.24", publicIP: nil),
        gpu: GPUMetrics(utilization: 0.18, vramUsed: 1_640 * mb, vramTotal: nil, temperature: 47),
        systemInfo: SystemInfoMetrics(hostname: "Alex’s MacBook Pro", username: "Alex Morgan",
                                      osVersion: osVersion, modelName: modelName, uptime: uptime),
        uptime: uptime
    )

    /// Two minutes of history (60 samples, 2 s apart) ending at the current values.
    static func history(_ base: Double, swing: Double, spikes: [Int: Double] = [:], seed: Double) -> [(Date, Double)] {
        (0..<60).map { i in
            let t = Double(i)
            var v = base + swing * (0.55 * sin(t / 4.3 + seed) + 0.3 * sin(t / 1.9 + seed * 2.1) + 0.15 * sin(t / 0.9 + seed * 3.7))
            if let s = spikes[i] { v = s }
            if i == 59 { v = base }
            return (now.addingTimeInterval(Double(i - 59) * 2), min(max(v, 0), 1))
        }
    }
}

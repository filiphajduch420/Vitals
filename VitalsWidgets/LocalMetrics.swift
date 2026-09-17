import Foundation
import IOKit
import IOKit.ps
import os

/// Stateless metric readers compiled into the widget extension so the Storage
/// and Battery widgets can render real data even when the App Group container
/// is unavailable (unsigned builds) or its `metrics.json` is stale.
///
/// Both reads work inside the widget's sandbox: disk capacity via `statfs`
/// (`URL.resourceValues`, matching Finder's free-space figure) and battery via
/// IOPowerSources plus IORegistry `AppleSmartBattery` for health and cycles.
/// The readers are one-shot — no caching — because the widget process is
/// short-lived and each timeline pass gets a fresh value.
enum LocalMetrics {

    // MARK: - Disk

    /// Reads capacity and free space for the boot volume. Disk I/O throughput
    /// is not measurable from a one-shot widget process (it needs two samples
    /// over time), so read/write speeds are reported as 0.
    static func readDisk() -> DiskMetrics {
        let url = URL(fileURLWithPath: "/")
        var totalSpace: UInt64 = 0
        var freeSpace: UInt64 = 0
        do {
            let values = try url.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
            ])
            totalSpace = UInt64(values.volumeTotalCapacity ?? 0)
            freeSpace = UInt64(values.volumeAvailableCapacityForImportantUsage ?? 0)
        } catch {
            VitalsLog.widgets.error("LocalMetrics.readDisk failed: \(error.localizedDescription)")
        }
        let usedSpace = totalSpace > freeSpace ? totalSpace - freeSpace : 0
        return DiskMetrics(
            totalSpace: totalSpace,
            usedSpace: usedSpace,
            freeSpace: freeSpace,
            readSpeed: 0,
            writeSpeed: 0
        )
    }

    // MARK: - Battery

    /// Reads charge level plus, via IORegistry, health (current vs design
    /// capacity) and cycle count. Returns nil on desktop Macs without a battery.
    static func readBattery() -> BatteryMetrics? {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array

        // No battery is normal on a desktop Mac, so this is not an error.
        guard let firstSource = sources.first else { return nil }

        guard let info = IOPSGetPowerSourceDescription(snapshot, firstSource).takeUnretainedValue() as? [String: Any] else {
            VitalsLog.widgets.error("LocalMetrics.readBattery: failed to read power source description")
            return nil
        }

        let percentage = info[kIOPSCurrentCapacityKey] as? Int ?? 0
        let isCharging = (info[kIOPSIsChargingKey] as? Bool) ?? false
        let powerSource = info[kIOPSPowerSourceStateKey] as? String
        let isPluggedIn = powerSource == kIOPSACPowerValue

        var timeRemaining: TimeInterval?
        if let minutes = info[kIOPSTimeToEmptyKey] as? Int, minutes >= 0 {
            timeRemaining = TimeInterval(minutes * 60)
        } else if let minutes = info[kIOPSTimeToFullChargeKey] as? Int, minutes >= 0, isCharging {
            timeRemaining = TimeInterval(minutes * 60)
        }

        // Health values live in IORegistry AppleSmartBattery — same keys the
        // main app's BatteryMonitor uses. AppleRawMaxCapacity / DesignCapacity
        // (mAh) give the health percentage; CycleCount is the wear indicator.
        let cycleCount = readSmartBatteryValue("CycleCount") as? Int
        // On Apple Silicon the capacity keys are nested inside the "BatteryData"
        // dictionary rather than top-level (top-level MaxCapacity is a percentage).
        let batteryData = readSmartBatteryValue("BatteryData") as? [String: Any]
        let maxCapacity = readSmartBatteryValue("AppleRawMaxCapacity") as? Int
            ?? readSmartBatteryValue("NominalChargeCapacity") as? Int
            ?? batteryData?["NominalChargeCapacity"] as? Int
        let designCapacity = readSmartBatteryValue("DesignCapacity") as? Int
            ?? batteryData?["DesignCapacity"] as? Int

        return BatteryMetrics(
            percentage: percentage,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            timeRemaining: timeRemaining,
            cycleCount: cycleCount,
            maxCapacity: maxCapacity,
            designCapacity: designCapacity
        )
    }

    private static func readSmartBatteryValue(_ key: String) -> Any? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else {
            VitalsLog.widgets.error("LocalMetrics: AppleSmartBattery service not found (key=\(key, privacy: .public))")
            return nil
        }
        defer { IOObjectRelease(service) }
        return IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    // MARK: - System info

    /// Reads the exact boot instant via `sysctl(KERN_BOOTTIME)`. Handing this
    /// fixed `Date` to `Text(_:style:.relative)` lets SwiftUI tick the uptime
    /// live inside the widget process with no timeline refreshes. Falls back to
    /// deriving the boot date from `ProcessInfo.systemUptime` if sysctl fails.
    static func readBootDate() -> Date {
        var boot = timeval()
        var size = MemoryLayout<timeval>.stride
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        if sysctl(&mib, 2, &boot, &size, nil, 0) == 0, boot.tv_sec != 0 {
            return Date(timeIntervalSince1970: TimeInterval(boot.tv_sec) + TimeInterval(boot.tv_usec) / 1_000_000)
        }
        VitalsLog.systemInfo.error("LocalMetrics.readBootDate: sysctl KERN_BOOTTIME failed (errno=\(errno, privacy: .public))")
        return Date(timeIntervalSinceNow: -ProcessInfo.processInfo.systemUptime)
    }

    /// Human-readable macOS version string, e.g. "macOS 26.0.1".
    static func readOSVersion() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    /// Hardware model identifier via `sysctl hw.model` (e.g. "Mac15,3"), matching
    /// the main app's `SystemInfoMonitor`. Returns "Mac" if the read fails.
    static func readModelName() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else {
            VitalsLog.systemInfo.warning("LocalMetrics.readModelName: sysctl hw.model returned no data")
            return "Mac"
        }
        var model = [UInt8](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(decoding: model.prefix(while: { $0 != 0 }), as: UTF8.self)
    }
}

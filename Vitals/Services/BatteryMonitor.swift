import Foundation
import IOKit.ps
import os

final class BatteryMonitor: @unchecked Sendable {

    // MARK: - Cache for slowly-changing IOKit values

    // DesignCapacity never changes — read once and keep forever.
    private var cachedDesignCapacity: Int?
    private var designCapacityLoaded = false
    // CycleCount / maxCapacity change slowly — refresh every 5 minutes.
    private var cachedCycleCount: Int?
    private var cachedMaxCapacity: Int?
    private var lastBatteryHealthRefresh: Date = .distantPast

    var isAvailable: Bool {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        return !sources.isEmpty
    }

    func read() -> BatteryMetrics? {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array

        guard let firstSource = sources.first else {
            VitalsLog.battery.error("no power sources available")
            return nil
        }

        guard let info = IOPSGetPowerSourceDescription(snapshot, firstSource).takeUnretainedValue() as? [String: Any] else {
            VitalsLog.battery.error("failed to read power source description")
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

        // Cycle count and max capacity change slowly — cache with 5-minute TTL
        if cachedCycleCount == nil || Date().timeIntervalSince(lastBatteryHealthRefresh) >= 300 {
            lastBatteryHealthRefresh = Date()
            cachedCycleCount = readSmartBatteryValue("CycleCount") as? Int
            // Battery health: AppleRawMaxCapacity (mAh) vs DesignCapacity (mAh)
            cachedMaxCapacity = readSmartBatteryValue("AppleRawMaxCapacity") as? Int
                ?? readSmartBatteryValue("NominalChargeCapacity") as? Int
        }
        let cycleCount = cachedCycleCount
        let maxCapacity = cachedMaxCapacity

        // DesignCapacity never changes — read once and keep forever
        if !designCapacityLoaded {
            cachedDesignCapacity = readSmartBatteryValue("DesignCapacity") as? Int
            designCapacityLoaded = true
        }
        let designCapacity = cachedDesignCapacity

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

    private func readSmartBatteryValue(_ key: String) -> Any? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else {
            VitalsLog.battery.error("AppleSmartBattery service not found (key=\(key, privacy: .public))")
            return nil
        }
        defer { IOObjectRelease(service) }
        return IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}

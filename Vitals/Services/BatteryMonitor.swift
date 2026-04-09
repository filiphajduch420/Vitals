import Foundation
import IOKit.ps

final class BatteryMonitor: Sendable {

    var isAvailable: Bool {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        return !sources.isEmpty
    }

    func read() -> BatteryMetrics? {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array

        guard let firstSource = sources.first else { return nil }

        guard let info = IOPSGetPowerSourceDescription(snapshot, firstSource).takeUnretainedValue() as? [String: Any] else {
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

        // Cycle count from IOKit
        let cycleCount = readSmartBatteryValue("CycleCount") as? Int

        // Battery health: AppleRawMaxCapacity (mAh) vs DesignCapacity (mAh)
        let maxCapacity = readSmartBatteryValue("AppleRawMaxCapacity") as? Int
            ?? readSmartBatteryValue("NominalChargeCapacity") as? Int
        let designCapacity = readSmartBatteryValue("DesignCapacity") as? Int

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
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }
        return IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}

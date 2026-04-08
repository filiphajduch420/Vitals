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

        let cycleCount = info["BatteryHealth" as String] != nil
            ? info[kIOPSBatteryHealthKey] as? Int
            : nil

        return BatteryMetrics(
            percentage: percentage,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            timeRemaining: timeRemaining,
            cycleCount: cycleCount
        )
    }
}

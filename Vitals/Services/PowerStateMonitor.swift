import Foundation
import IOKit
import IOKit.ps

@MainActor
@Observable
final class PowerStateMonitor {

    var isOnBattery: Bool = false
    var onStateChanged: (() -> Void)?

    private nonisolated(unsafe) var runLoopSource: CFRunLoopSource?

    init() {
        isOnBattery = Self.checkBatteryState()
        startObserving()
    }

    deinit {
        Unmanaged.passUnretained(self).release()
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    // MARK: - Private

    private func startObserving() {
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let monitor = Unmanaged<PowerStateMonitor>.fromOpaque(context).takeUnretainedValue()
            let onBattery = PowerStateMonitor.checkBatteryState()
            Task { @MainActor in
                let changed = monitor.isOnBattery != onBattery
                monitor.isOnBattery = onBattery
                if changed { monitor.onStateChanged?() }
            }
        }

        let context = Unmanaged.passRetained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    private static func checkBatteryState() -> Bool {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array

        guard let firstSource = sources.first else { return false }

        guard let info = IOPSGetPowerSourceDescription(snapshot, firstSource)?.takeUnretainedValue() as? [String: Any] else {
            return false
        }

        let powerSource = info[kIOPSPowerSourceStateKey] as? String
        return powerSource != kIOPSACPowerValue
    }
}

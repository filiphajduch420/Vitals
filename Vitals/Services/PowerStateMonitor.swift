import Foundation
import IOKit
import IOKit.ps
import os

@MainActor
@Observable
final class PowerStateMonitor {

    var isOnBattery: Bool = false
    var onStateChanged: (() -> Void)?

    private nonisolated(unsafe) var runLoopSource: CFRunLoopSource?
    private var retainedContext: Unmanaged<PowerStateMonitor>?

    init() {
        isOnBattery = Self.checkBatteryState()
        startObserving()
    }

    deinit {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    /// Balances the `passRetained(self)` taken in `startObserving()`: removes the
    /// run-loop source and releases the retained callback context. Not called for
    /// the app-lifetime singleton, but keeps the retain/release pattern correct.
    func stopObserving() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
        }
        retainedContext?.release()
        retainedContext = nil
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
                if changed {
                    VitalsLog.power.info("power source changed: onBattery=\(onBattery ? "true" : "false", privacy: .public)")
                    monitor.onStateChanged?()
                }
            }
        }

        let unmanaged = Unmanaged.passRetained(self)
        retainedContext = unmanaged
        let context = unmanaged.toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        } else {
            VitalsLog.power.error("failed to create power-source notification run loop source")
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

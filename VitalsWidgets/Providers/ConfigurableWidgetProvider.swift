import WidgetKit
import os

// MARK: - Shared timeline entry

struct VitalsEntry: TimelineEntry {
    let date: Date
    let metrics: SystemMetrics
}

// MARK: - Local-metrics provider (Storage & Battery)

/// Provider for widgets whose data can be computed inside the widget sandbox
/// (Storage, Battery). These never depend on the App Group container: they read
/// disk and battery directly, so a fresh, signed app is not required to see real
/// values. Very recent shared metrics are still preferred when the app is
/// running, otherwise the local read is both the default and the fallback.
struct LocalMetricsProvider: TimelineProvider {

    /// Shared metrics are only preferred while very fresh; past this the widget
    /// computes locally so the reading is never misleadingly old.
    private static let preferSharedMaxAge: TimeInterval = 60 // 1 minute

    /// Prefer very fresh shared metrics if present, else compute disk/battery
    /// locally. Local computation is the default path and the fallback.
    private func currentMetrics() -> SystemMetrics {
        if let shared = DataSharingManager.readMetrics() {
            let age = Date.now.timeIntervalSince(shared.timestamp)
            if age <= Self.preferSharedMaxAge {
                // Success path runs on every refresh, so keep it at .debug.
                VitalsLog.widgets.debug("using fresh shared metrics age=\(Int(age), privacy: .public)s")
                return shared
            }
        }
        var metrics = SystemMetrics.empty
        metrics.disk = LocalMetrics.readDisk()
        metrics.battery = LocalMetrics.readBattery()
        return metrics
    }

    func placeholder(in context: Context) -> VitalsEntry {
        VitalsEntry(date: .now, metrics: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (VitalsEntry) -> Void) {
        completion(VitalsEntry(date: .now, metrics: currentMetrics()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VitalsEntry>) -> Void) {
        let entry = VitalsEntry(date: .now, metrics: currentMetrics())
        // The app nudges refreshes while running; .after keeps the WidgetKit
        // refresh budget sane otherwise.
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

// MARK: - System-info provider (Uptime)

/// Timeline entry for the System Info widget. Everything here is read locally in
/// the widget process, so it never depends on the App Group container.
struct SystemInfoEntry: TimelineEntry {
    let date: Date
    let bootDate: Date
    let osVersion: String
    let modelName: String
}

/// Provider for the System Info / Uptime widget. The boot instant, macOS version
/// and Mac model are read directly via sysctl (`LocalMetrics`), so no signed app
/// or shared JSON is required. The boot `Date` is captured once and rendered with
/// `Text(_:style:.relative)`, which SwiftUI ticks live without any timeline
/// refreshes — so the timeline is essentially static and only refreshes hourly to
/// catch an OS update or a reboot that happened while the widget was idle.
struct SystemInfoProvider: TimelineProvider {

    private func currentEntry() -> SystemInfoEntry {
        SystemInfoEntry(
            date: .now,
            bootDate: LocalMetrics.readBootDate(),
            osVersion: LocalMetrics.readOSVersion(),
            modelName: LocalMetrics.readModelName()
        )
    }

    func placeholder(in context: Context) -> SystemInfoEntry {
        SystemInfoEntry(
            date: .now,
            bootDate: Date(timeIntervalSinceNow: -3 * 60 * 60),
            osVersion: "macOS 26.0",
            modelName: "Mac"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SystemInfoEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SystemInfoEntry>) -> Void) {
        let entry = currentEntry()
        // Uptime ticks client-side via Text(_:style:.relative); the timeline
        // itself only needs an hourly safety-net refresh.
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 60))))
    }
}

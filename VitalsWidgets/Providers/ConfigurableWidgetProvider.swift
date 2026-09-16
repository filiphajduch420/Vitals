import WidgetKit
@preconcurrency import AppIntents
import os

// MARK: - Shared timeline entry

struct VitalsEntry: TimelineEntry {
    let date: Date
    let metrics: SystemMetrics
}

// MARK: - Shared provider

struct VitalsTimelineProvider: TimelineProvider {

    /// Maximum age (in seconds) before shared metrics are considered stale.
    private static let maxDataAge: TimeInterval = 5 * 60 // 5 minutes

    /// Read metrics and discard them if they are older than `maxDataAge`.
    private func freshMetrics() -> SystemMetrics {
        guard let m = DataSharingManager.readMetrics() else {
            VitalsLog.widgets.error("no shared metrics available — widget shows empty state")
            return .empty
        }
        let age = Date.now.timeIntervalSince(m.timestamp)
        if age > Self.maxDataAge {
            VitalsLog.widgets.warning("shared metrics stale: age=\(Int(age), privacy: .public)s — showing empty state")
            return .empty // stale data — show "no data" state
        }
        // Success path runs on every widget refresh, so keep it at .debug.
        VitalsLog.widgets.debug("shared metrics age=\(Int(age), privacy: .public)s")
        return m
    }

    func placeholder(in context: Context) -> VitalsEntry {
        VitalsEntry(date: .now, metrics: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (VitalsEntry) -> Void) {
        completion(VitalsEntry(date: .now, metrics: freshMetrics()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VitalsEntry>) -> Void) {
        let entry = VitalsEntry(date: .now, metrics: freshMetrics())
        // The app drives refreshes via reloadAllTimelines() every 30 s while running.
        // Use .after as a safety net for when the app is not running, instead of .atEnd
        // which would immediately request a new timeline and burn the refresh budget.
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

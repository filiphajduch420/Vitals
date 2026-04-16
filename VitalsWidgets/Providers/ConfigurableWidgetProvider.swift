import WidgetKit
@preconcurrency import AppIntents

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
        guard let m = DataSharingManager.readMetrics() else { return .empty }
        let age = Date.now.timeIntervalSince(m.timestamp)
        if age > Self.maxDataAge {
            return .empty // stale data — show "no data" state
        }
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
        completion(Timeline(entries: [entry], policy: .atEnd))
    }
}

import WidgetKit
@preconcurrency import AppIntents

// MARK: - Shared timeline entry

struct VitalsEntry: TimelineEntry {
    let date: Date
    let metrics: SystemMetrics
}

// MARK: - Shared provider

struct VitalsTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> VitalsEntry {
        VitalsEntry(date: .now, metrics: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (VitalsEntry) -> Void) {
        let m = DataSharingManager.readMetrics() ?? .empty
        completion(VitalsEntry(date: .now, metrics: m))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VitalsEntry>) -> Void) {
        let m = DataSharingManager.readMetrics() ?? .empty
        let entry = VitalsEntry(date: .now, metrics: m)
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

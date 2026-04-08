import Foundation

struct MetricSnapshot: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let value: Double   // 0.0 – 1.0 normalized
}

struct MetricHistory: Sendable {
    private var snapshots: [MetricSnapshot]
    let capacity: Int

    init(capacity: Int = 60) {
        self.capacity = capacity
        self.snapshots = []
    }

    var values: [MetricSnapshot] { snapshots }

    var latest: Double { snapshots.last?.value ?? 0 }

    mutating func append(_ value: Double, at date: Date = .now) {
        let snapshot = MetricSnapshot(timestamp: date, value: value)
        snapshots.append(snapshot)
        if snapshots.count > capacity {
            snapshots.removeFirst(snapshots.count - capacity)
        }
    }
}

import Foundation

struct MetricSnapshot: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let value: Double   // 0.0 – 1.0 normalized
}

struct MetricHistory: Sendable {
    private var buffer: [MetricSnapshot]
    private var head: Int = 0
    private var count_: Int = 0
    let capacity: Int

    init(capacity: Int = 60) {
        self.capacity = capacity
        self.buffer = Array(repeating: MetricSnapshot(timestamp: .distantPast, value: 0), count: capacity)
    }

    var values: [MetricSnapshot] {
        guard count_ > 0 else { return [] }
        if count_ < capacity {
            let start = (head - count_ + capacity) % capacity
            if start < head {
                return Array(buffer[start..<head])
            } else {
                return Array(buffer[start..<capacity]) + Array(buffer[0..<head])
            }
        } else {
            return Array(buffer[head..<capacity]) + Array(buffer[0..<head])
        }
    }

    var latest: Double { count_ > 0 ? buffer[(head - 1 + capacity) % capacity].value : 0 }

    mutating func append(_ value: Double, at date: Date = .now) {
        buffer[head] = MetricSnapshot(timestamp: date, value: value)
        head = (head + 1) % capacity
        if count_ < capacity { count_ += 1 }
    }
}

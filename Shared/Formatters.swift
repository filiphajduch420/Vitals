import Foundation

enum Formatters {

    // MARK: - Bytes

    // Cached instance — allocating a ByteCountFormatter on every call is wasteful
    // since formatBytes runs each tick from the menu bar label. Configured once and
    // only read afterwards.
    nonisolated(unsafe) private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useAll]
        f.countStyle = .memory
        return f
    }()

    static func formatBytes(_ bytes: UInt64) -> String {
        byteFormatter.string(fromByteCount: Int64(bytes))
    }

    // MARK: - Bytes/sec (network speed)

    static func formatBytesPerSec(_ bytesPerSec: UInt64) -> String {
        let bps = Double(bytesPerSec)
        switch bps {
        case 0..<1024:
            return "\(Int(bps)) B/s"
        case 1024..<(1024 * 1024):
            return String(format: "%.1f KB/s", bps / 1024)
        case (1024 * 1024)..<(1024 * 1024 * 1024):
            return String(format: "%.1f MB/s", bps / (1024 * 1024))
        default:
            return String(format: "%.2f GB/s", bps / (1024 * 1024 * 1024))
        }
    }

    // MARK: - Duration

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    // MARK: - Percentage

    static func formatPercent(_ ratio: Double) -> String {
        "\(Int(ratio * 100))%"
    }

    /// Formats an already-computed CPU percentage (0…N, may exceed 100 for
    /// multi-threaded processes). Shows one decimal place below 10% so small but
    /// non-zero consumers stay visible (e.g. "3.4%"), and whole numbers at or
    /// above 10% to keep the top-processes list compact.
    static func formatCPUPercent(_ percent: Double) -> String {
        let value = max(0, percent)
        // Locale-aware decimal separator so the card matches ByteCountFormatter output.
        let digits = value < 10 ? 1 : 0
        return value.formatted(.number.precision(.fractionLength(digits))) + "%"
    }
}

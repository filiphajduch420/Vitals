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
}

import Foundation
import Darwin

final class NetworkMonitor: @unchecked Sendable {

    private struct Reading {
        let timestamp: Date
        let bytesIn: UInt64
        let bytesOut: UInt64
    }

    private var previousReading: Reading?

    func read() -> NetworkMetrics {
        let (bytesIn, bytesOut) = readInterfaceBytes()
        let now = Date()

        defer {
            previousReading = Reading(
                timestamp: now,
                bytesIn: bytesIn,
                bytesOut: bytesOut
            )
        }

        guard let prev = previousReading else {
            return NetworkMetrics(
                uploadSpeed: 0,
                downloadSpeed: 0,
                totalUploaded: bytesOut,
                totalDownloaded: bytesIn
            )
        }

        let elapsed = now.timeIntervalSince(prev.timestamp)
        guard elapsed > 0 else { return .empty }

        let downloadDelta = bytesIn >= prev.bytesIn ? bytesIn - prev.bytesIn : 0
        let uploadDelta = bytesOut >= prev.bytesOut ? bytesOut - prev.bytesOut : 0

        let downloadSpeed = UInt64(Double(downloadDelta) / elapsed)
        let uploadSpeed = UInt64(Double(uploadDelta) / elapsed)

        return NetworkMetrics(
            uploadSpeed: uploadSpeed,
            downloadSpeed: downloadSpeed,
            totalUploaded: bytesOut,
            totalDownloaded: bytesIn
        )
    }

    private func readInterfaceBytes() -> (bytesIn: UInt64, bytesOut: UInt64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return (0, 0)
        }
        defer { freeifaddrs(ifaddr) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = cursor {
            let flags = Int32(addr.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0

            // Only count AF_LINK (data link layer) on active, non-loopback interfaces
            if isUp && !isLoopback && addr.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                addr.pointee.ifa_data.withMemoryRebound(to: if_data.self, capacity: 1) { data in
                    totalIn += UInt64(data.pointee.ifi_ibytes)
                    totalOut += UInt64(data.pointee.ifi_obytes)
                }
            }
            cursor = addr.pointee.ifa_next
        }

        return (totalIn, totalOut)
    }
}

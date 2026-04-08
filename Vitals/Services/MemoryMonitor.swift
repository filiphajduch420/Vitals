import Foundation
import Darwin

final class MemoryMonitor: Sendable {

    func read() -> MemoryMetrics {
        let totalBytes = ProcessInfo.processInfo.physicalMemory

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(
                    mach_host_self(),
                    HOST_VM_INFO64,
                    intPtr,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            return MemoryMetrics(
                total: totalBytes, used: 0, free: totalBytes,
                active: 0, inactive: 0, wired: 0, compressed: 0,
                pressure: .nominal
            )
        }

        let pageSize = UInt64(sysconf(_SC_PAGESIZE))

        let active     = UInt64(stats.active_count) * pageSize
        let inactive   = UInt64(stats.inactive_count) * pageSize
        let wired      = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let _          = UInt64(stats.free_count) * pageSize

        // "Used" = active + wired + compressed (excludes inactive/free)
        let used = active + wired + compressed
        let actualFree = totalBytes - min(used, totalBytes)

        let pressure: MemoryPressureLevel
        let usageRatio = Double(used) / Double(totalBytes)
        if usageRatio > 0.9 {
            pressure = .critical
        } else if usageRatio > 0.75 {
            pressure = .warning
        } else {
            pressure = .nominal
        }

        return MemoryMetrics(
            total: totalBytes,
            used: used,
            free: actualFree,
            active: active,
            inactive: inactive,
            wired: wired,
            compressed: compressed,
            pressure: pressure
        )
    }
}

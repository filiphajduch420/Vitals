import Foundation
import Darwin
import os

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
            VitalsLog.memory.error("host_statistics64 failed: kr=\(result, privacy: .public)")
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

        let pressure = readPressureLevel()

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

    // Reads the real kernel memory pressure level instead of deriving it from
    // the RAM usage ratio (a healthy macOS routinely sits well above 75% used).
    // kern.memorystatus_vm_pressure_level: 1 = normal, 2 = warning, 4 = critical.
    private func readPressureLevel() -> MemoryPressureLevel {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0)
        guard result == 0 else {
            VitalsLog.memory.error("sysctl kern.memorystatus_vm_pressure_level failed: errno=\(errno, privacy: .public)")
            return .nominal
        }
        switch level {
        case 2:  return .warning
        case 4:  return .critical
        default: return .nominal
        }
    }
}

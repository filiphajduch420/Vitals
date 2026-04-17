import Foundation
import IOKit

final class DiskMonitor: @unchecked Sendable {

    private var prevReadBytes: UInt64 = 0
    private var prevWriteBytes: UInt64 = 0
    private var prevTime: Date?

    func read() -> DiskMetrics {
        // Disk space
        let url = URL(fileURLWithPath: "/")
        var totalSpace: UInt64 = 0
        var freeSpace: UInt64 = 0
        if let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
        ]) {
            totalSpace = UInt64(values.volumeTotalCapacity ?? 0)
            freeSpace = UInt64(values.volumeAvailableCapacityForImportantUsage ?? 0)
        }
        let usedSpace = totalSpace > freeSpace ? totalSpace - freeSpace : 0

        // Disk I/O
        let (readBytes, writeBytes) = readDiskIOBytes()
        let now = Date()
        var readSpeed: UInt64 = 0
        var writeSpeed: UInt64 = 0

        if let prev = prevTime {
            let elapsed = now.timeIntervalSince(prev)
            if elapsed > 0 {
                let readDelta = readBytes >= prevReadBytes ? readBytes - prevReadBytes : 0
                let writeDelta = writeBytes >= prevWriteBytes ? writeBytes - prevWriteBytes : 0
                readSpeed = UInt64(Double(readDelta) / elapsed)
                writeSpeed = UInt64(Double(writeDelta) / elapsed)
            }
        }
        prevReadBytes = readBytes
        prevWriteBytes = writeBytes
        prevTime = now

        return DiskMetrics(
            totalSpace: totalSpace,
            usedSpace: usedSpace,
            freeSpace: freeSpace,
            readSpeed: readSpeed,
            writeSpeed: writeSpeed
        )
    }

    private func readDiskIOBytes() -> (read: UInt64, write: UInt64) {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOBlockStorageDriver"),
            &iterator
        ) == KERN_SUCCESS else { return (0, 0) }
        defer { IOObjectRelease(iterator) }

        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0

        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            let current = entry
            defer { IOObjectRelease(current) }
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(entry, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any],
               let stats = dict["Statistics"] as? [String: Any] {
                totalRead += stats["Bytes (Read)"] as? UInt64 ?? 0
                totalWrite += stats["Bytes (Write)"] as? UInt64 ?? 0
            }
            entry = IOIteratorNext(iterator)
        }
        return (totalRead, totalWrite)
    }
}

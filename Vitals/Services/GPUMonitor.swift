import Foundation
import IOKit

final class GPUMonitor: @unchecked Sendable {

    func read(gpuTemp: Double?) -> GPUMetrics {
        var utilization: Double?
        var vramUsed: UInt64?
        var vramTotal: UInt64?

        // Try Apple Silicon GPU (AGXAccelerator)
        let matching = IOServiceMatching("AGXAccelerator")
        var iterator: io_iterator_t = 0

        if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS {
            defer { IOObjectRelease(iterator) }
            var service = IOIteratorNext(iterator)
            while service != IO_OBJECT_NULL {
                // GPU utilization
                if let props = getProperties(service) {
                    if let perf = props["PerformanceStatistics"] as? [String: Any] {
                        // Device Utilization % on Apple Silicon
                        if let util = perf["Device Utilization %"] as? NSNumber {
                            utilization = util.doubleValue / 100.0
                        } else if let util = perf["GPU Activity(%)"] as? NSNumber {
                            utilization = util.doubleValue / 100.0
                        }
                        // VRAM
                        if let used = perf["vramUsedBytes"] as? UInt64 {
                            vramUsed = used
                        } else if let used = perf["Alloc system memory"] as? UInt64 {
                            vramUsed = used
                        }
                    }
                    if let total = props["VRAM,totalMB"] as? UInt64 {
                        vramTotal = total * 1024 * 1024
                    }
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
        }

        // Fallback: try Intel/AMD GPU
        if utilization == nil {
            if let accelMatching = IOServiceMatching("IOAccelerator") {
                var accelIterator: io_iterator_t = 0
                if IOServiceGetMatchingServices(kIOMainPortDefault, accelMatching, &accelIterator) == KERN_SUCCESS {
                    defer { IOObjectRelease(accelIterator) }
                    var service = IOIteratorNext(accelIterator)
                    while service != IO_OBJECT_NULL {
                        if let props = getProperties(service) {
                            if let perf = props["PerformanceStatistics"] as? [String: Any] {
                                if let util = perf["GPU Core Utilization"] as? NSNumber {
                                    utilization = util.doubleValue / 100.0
                                }
                                if let used = perf["vramUsedBytes"] as? UInt64 {
                                    vramUsed = used
                                }
                            }
                            if let total = props["VRAM,totalMB"] as? UInt64 {
                                vramTotal = total * 1024 * 1024
                            }
                        }
                        IOObjectRelease(service)
                        service = IOIteratorNext(accelIterator)
                    }
                }
            }
        }

        return GPUMetrics(
            utilization: utilization,
            vramUsed: vramUsed,
            vramTotal: vramTotal,
            temperature: gpuTemp
        )
    }

    private func getProperties(_ service: io_object_t) -> [String: Any]? {
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS else {
            return nil
        }
        return props?.takeRetainedValue() as? [String: Any]
    }
}

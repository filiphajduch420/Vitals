import Foundation
import Darwin

final class CPUMonitor: @unchecked Sendable {

    private struct Ticks {
        var user: Double = 0
        var system: Double = 0
        var idle: Double = 0
        var nice: Double = 0
    }

    private var previousTicks = Ticks()

    func read() -> CPUMetrics {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return .empty
        }

        defer {
            let size = vm_size_t(
                MemoryLayout<integer_t>.stride * Int(numCPUInfo)
            )
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
        }

        var currentTicks = Ticks()

        for core in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * core
            currentTicks.user   += Double(info[offset + Int(CPU_STATE_USER)])
            currentTicks.system += Double(info[offset + Int(CPU_STATE_SYSTEM)])
            currentTicks.idle   += Double(info[offset + Int(CPU_STATE_IDLE)])
            currentTicks.nice   += Double(info[offset + Int(CPU_STATE_NICE)])
        }

        // Calculate delta from previous reading
        let deltaUser   = currentTicks.user - previousTicks.user
        let deltaSystem = currentTicks.system - previousTicks.system
        let deltaIdle   = currentTicks.idle - previousTicks.idle
        let deltaNice   = currentTicks.nice - previousTicks.nice

        previousTicks = currentTicks

        let deltaTotal = deltaUser + deltaSystem + deltaIdle + deltaNice
        guard deltaTotal > 0 else { return .empty }

        let userRatio   = (deltaUser + deltaNice) / deltaTotal
        let systemRatio = deltaSystem / deltaTotal
        let idleRatio   = deltaIdle / deltaTotal
        let usageRatio  = 1.0 - idleRatio

        return CPUMetrics(
            totalUsage: usageRatio,
            userUsage: userRatio,
            systemUsage: systemRatio,
            idleUsage: idleRatio,
            activeCores: ProcessInfo.processInfo.activeProcessorCount,
            totalCores: ProcessInfo.processInfo.processorCount
        )
    }
}

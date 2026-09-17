import Foundation
import Darwin
import os

/// A single process' resource usage, resolved on demand for the "Top Processes"
/// lists in the CPU and Memory popover details.
struct ProcessUsage: Identifiable, Sendable, Hashable {
    let pid: pid_t
    let name: String
    /// Percent of a single core; can exceed 100% for multi-threaded processes,
    /// matching Activity Monitor.
    let cpuPercent: Double
    let memoryBytes: UInt64

    var id: pid_t { pid }
}

/// Enumerates running processes and reports the top consumers of CPU and RAM.
///
/// The main app is not sandboxed, so `proc_listallpids` + `proc_pidinfo` can read
/// task info for the user's processes without extra entitlements (privileged
/// daemons owned by other users are simply skipped).
///
/// **Battery:** this is deliberately *not* wired into the 2 s polling tick. It is
/// sampled on demand only while a CPU/Memory popover detail is visible (~3 s
/// timer), and a short TTL cache plus an in-flight guard collapse the two detail
/// views' overlapping refreshes into a single process scan.
actor ProcessMonitor {

    struct Snapshot: Sendable {
        let byCPU: [ProcessUsage]
        let byMemory: [ProcessUsage]

        static let empty = Snapshot(byCPU: [], byMemory: [])
    }

    /// Raw per-process sample before names are resolved (name lookup is an extra
    /// syscall per PID, so it is deferred to the handful of processes that make
    /// the top lists).
    private struct RawProcess {
        let pid: pid_t
        let cpuPercent: Double
        let memoryBytes: UInt64
    }

    /// Cumulative CPU time (user + system) from the previous sample, per PID.
    /// Stored in the raw mach absolute-time units reported by
    /// `PROC_PIDTASKINFO`; converted to nanoseconds only when the delta is
    /// turned into a percentage (see `machToNanos`).
    private var previousCPUTimes: [pid_t: UInt64] = [:]
    private var previousSampleTime: Date = .distantPast

    /// Mach timebase used to convert `pti_total_user`/`pti_total_system` into
    /// nanoseconds. Those fields come from `TASK_ABSOLUTETIME_INFO`, which — the
    /// misleading name notwithstanding — reports mach absolute-time *ticks*, not
    /// nanoseconds. On Apple Silicon the ratio is typically 125/3 (so treating a
    /// tick as a nanosecond undercounts CPU time ~42×, which is why percentages
    /// read as ~0%); on Intel it is 1/1.
    private let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        let result = mach_timebase_info(&info)
        guard result == KERN_SUCCESS, info.numer != 0, info.denom != 0 else {
            VitalsLog.processes.error(
                "mach_timebase_info failed (\(result, privacy: .public)); falling back to 1:1"
            )
            return mach_timebase_info_data_t(numer: 1, denom: 1)
        }
        return info
    }()

    private var cached: Snapshot?
    private var lastRefresh: Date = .distantPast
    private var inFlight: Task<Snapshot, Never>?

    /// Serve a cached result to callers within this window so the CPU and Memory
    /// details don't each trigger a scan when the popover opens.
    private let cacheTTL: TimeInterval = 2
    /// When the previous sample is older than this the CPU delta would be
    /// meaningless (e.g. the popover was closed for a while), so re-seed instead.
    private let staleInterval: TimeInterval = 30
    /// Delay between the seeding sample and the first real sample so a freshly
    /// opened popover shows meaningful CPU percentages immediately.
    private let seedDelay: Duration = .milliseconds(400)

    func topProcesses(limit: Int = 5) async -> Snapshot {
        if let cached, Date().timeIntervalSince(lastRefresh) < cacheTTL {
            return cached
        }
        if let inFlight {
            return await inFlight.value
        }

        let task = Task { () -> Snapshot in
            // Seed a baseline when there is none, or when the last one is too old
            // to yield a sensible CPU delta.
            if previousSampleTime == .distantPast
                || Date().timeIntervalSince(previousSampleTime) > staleInterval {
                _ = collect()
                try? await Task.sleep(for: seedDelay)
            }

            let processes = collect()
            let byCPU = processes.sorted { $0.cpuPercent > $1.cpuPercent }
                .prefix(limit).map { resolve($0) }
            let byMemory = processes.sorted { $0.memoryBytes > $1.memoryBytes }
                .prefix(limit).map { resolve($0) }

            let snapshot = Snapshot(byCPU: byCPU, byMemory: byMemory)
            cached = snapshot
            lastRefresh = Date()
            return snapshot
        }

        inFlight = task
        defer { inFlight = nil }
        return await task.value
    }

    // MARK: - Sampling

    /// Reads CPU time and resident size for every accessible PID and computes the
    /// CPU percentage as the delta against the previous sample.
    private func collect() -> [RawProcess] {
        let now = Date()
        let elapsed = now.timeIntervalSince(previousSampleTime)
        let hasBaseline = previousSampleTime != .distantPast
            && elapsed > 0
            && elapsed <= staleInterval

        let pids = currentPIDs()
        var newTimes: [pid_t: UInt64] = [:]
        newTimes.reserveCapacity(pids.count)
        var processes: [RawProcess] = []
        processes.reserveCapacity(pids.count)

        for pid in pids {
            guard let info = taskInfo(pid) else { continue }
            let cpuTime = info.pti_total_user &+ info.pti_total_system
            newTimes[pid] = cpuTime

            var cpuPercent = 0.0
            if hasBaseline, let previous = previousCPUTimes[pid], cpuTime >= previous {
                let deltaNanos = machToNanos(cpuTime - previous)
                cpuPercent = deltaNanos / 1_000_000_000 / elapsed * 100
            }

            processes.append(
                RawProcess(pid: pid, cpuPercent: cpuPercent, memoryBytes: info.pti_resident_size)
            )
        }

        previousCPUTimes = newTimes
        previousSampleTime = now
        return processes
    }

    /// Converts a mach absolute-time delta into nanoseconds via the cached
    /// timebase. Done in `Double` because the multiply by `numer` (up to 125 on
    /// Apple Silicon) would otherwise risk overflowing a large `UInt64` tick
    /// count; a per-process delta over a few seconds stays well within `Double`'s
    /// exact-integer range.
    private func machToNanos(_ ticks: UInt64) -> Double {
        Double(ticks) * Double(timebase.numer) / Double(timebase.denom)
    }

    private func resolve(_ raw: RawProcess) -> ProcessUsage {
        ProcessUsage(
            pid: raw.pid,
            name: processName(raw.pid),
            cpuPercent: raw.cpuPercent,
            memoryBytes: raw.memoryBytes
        )
    }

    // MARK: - libproc helpers

    private func currentPIDs() -> [pid_t] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else {
            VitalsLog.processes.error("proc_listallpids sizing failed: \(count, privacy: .public)")
            return []
        }

        // Over-allocate slightly in case processes spawn between the sizing call
        // and the fill call.
        let capacity = Int(count) + 32
        var pids = [pid_t](repeating: 0, count: capacity)
        let filled = proc_listallpids(&pids, Int32(capacity * MemoryLayout<pid_t>.size))
        guard filled > 0 else {
            VitalsLog.processes.error("proc_listallpids fill failed: \(filled, privacy: .public)")
            return []
        }

        return Array(pids.prefix(Int(filled)))
    }

    private func taskInfo(_ pid: pid_t) -> proc_taskinfo? {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        let result = proc_pidinfo(pid, Int32(PROC_PIDTASKINFO), 0, &info, size)
        // Returns 0 for processes we're not allowed to inspect (privileged
        // daemons); that's expected and not worth logging on every scan.
        guard result == size else { return nil }
        return info
    }

    private func processName(_ pid: pid_t) -> String {
        if pid == 0 { return "kernel_task" }

        var buffer = [CChar](repeating: 0, count: 256)
        let result = proc_name(pid, &buffer, UInt32(buffer.count))
        if result > 0 {
            let name = String(cString: buffer)
            if !name.isEmpty { return name }
        }
        return "PID \(pid)"
    }
}

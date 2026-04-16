import Foundation

actor SystemMonitor {

    private let cpuMonitor: CPUMonitor
    private let memoryMonitor: MemoryMonitor
    private let networkMonitor: NetworkMonitor
    private let batteryMonitor: BatteryMonitor
    private let diskMonitor: DiskMonitor
    private let thermalMonitor: ThermalMonitor
    private let wifiMonitor: WiFiMonitor
    private let gpuMonitor: GPUMonitor
    private let systemInfoMonitor: SystemInfoMonitor

    private var pollingTask: Task<Void, Never>?

    let hasBattery: Bool

    // MARK: - Battery saving mode

    private(set) var isBatterySaving: Bool = false

    func setBatterySaving(_ value: Bool) {
        isBatterySaving = value
    }
    private var cycleCount: Int = 0

    private var cachedThermal: ThermalMetrics?
    private var cachedGPU: GPUMetrics?
    private var cachedDiskSpeeds: (readSpeed: UInt64, writeSpeed: UInt64) = (0, 0)

    init() {
        cpuMonitor = CPUMonitor()
        memoryMonitor = MemoryMonitor()
        networkMonitor = NetworkMonitor()
        batteryMonitor = BatteryMonitor()
        diskMonitor = DiskMonitor()
        thermalMonitor = ThermalMonitor()
        wifiMonitor = WiFiMonitor()
        gpuMonitor = GPUMonitor()
        systemInfoMonitor = SystemInfoMonitor()
        hasBattery = BatteryMonitor().isAvailable
    }

    func startPolling(interval: TimeInterval, onUpdate: @MainActor @Sendable @escaping (SystemMetrics) -> Void) {
        stopPolling()
        cycleCount = 0
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let metrics = await self.collectMetrics()
                await onUpdate(metrics)
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func collectMetrics() async -> SystemMetrics {
        cycleCount += 1

        // Cheap metrics — always collected
        let cpu = cpuMonitor.read()
        let memory = memoryMonitor.read()
        let network = networkMonitor.read()
        let battery = hasBattery ? batteryMonitor.read() : nil
        let wifi = await wifiMonitor.read()
        let systemInfo = systemInfoMonitor.read()
        let uptime = ProcessInfo.processInfo.systemUptime

        let shouldCollectExpensive = !isBatterySaving || cycleCount % 3 == 0

        // Thermal
        let thermal: ThermalMetrics
        if shouldCollectExpensive {
            thermal = thermalMonitor.read()
            cachedThermal = thermal
        } else {
            thermal = cachedThermal ?? ThermalMetrics.empty
        }

        // GPU
        let gpu: GPUMetrics
        if shouldCollectExpensive {
            gpu = gpuMonitor.read(gpuTemp: thermal.gpuTemperature)
            cachedGPU = gpu
        } else {
            gpu = cachedGPU ?? GPUMetrics(utilization: nil, vramUsed: nil, vramTotal: nil, temperature: thermal.gpuTemperature)
        }

        // Disk — space is cheap (FileManager), IO speeds are expensive (IOKit)
        let disk: DiskMetrics
        if shouldCollectExpensive {
            disk = diskMonitor.read()
            cachedDiskSpeeds = (readSpeed: disk.readSpeed, writeSpeed: disk.writeSpeed)
        } else {
            // Read only disk space (cheap) and reuse cached IO speeds
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
            let speeds = cachedDiskSpeeds
            disk = DiskMetrics(
                totalSpace: totalSpace,
                usedSpace: usedSpace,
                freeSpace: freeSpace,
                readSpeed: speeds.readSpeed,
                writeSpeed: speeds.writeSpeed
            )
        }

        return SystemMetrics(
            timestamp: .now,
            cpu: cpu,
            memory: memory,
            network: network,
            battery: battery,
            disk: disk,
            thermal: thermal,
            wifi: wifi,
            gpu: gpu,
            systemInfo: systemInfo,
            uptime: uptime
        )
    }
}

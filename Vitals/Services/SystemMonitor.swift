import Foundation

actor SystemMonitor {

    private let cpuMonitor: CPUMonitor
    private let memoryMonitor: MemoryMonitor
    private let networkMonitor: NetworkMonitor
    private let batteryMonitor: BatteryMonitor
    private let diskMonitor: DiskMonitor
    private let thermalMonitor: ThermalMonitor
    private let wifiMonitor: WiFiMonitor
    private let systemInfoMonitor: SystemInfoMonitor

    private var pollingTask: Task<Void, Never>?

    let hasBattery: Bool

    init() {
        cpuMonitor = CPUMonitor()
        memoryMonitor = MemoryMonitor()
        networkMonitor = NetworkMonitor()
        batteryMonitor = BatteryMonitor()
        diskMonitor = DiskMonitor()
        thermalMonitor = ThermalMonitor()
        wifiMonitor = WiFiMonitor()
        systemInfoMonitor = SystemInfoMonitor()
        hasBattery = BatteryMonitor().isAvailable
    }

    func startPolling(interval: TimeInterval, onUpdate: @MainActor @Sendable @escaping (SystemMetrics) -> Void) {
        stopPolling()
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

    func collectMetrics() -> SystemMetrics {
        let cpu = cpuMonitor.read()
        let memory = memoryMonitor.read()
        let network = networkMonitor.read()
        let battery = hasBattery ? batteryMonitor.read() : nil
        let disk = diskMonitor.read()
        let thermal = thermalMonitor.read()
        let wifi = wifiMonitor.read()
        let systemInfo = systemInfoMonitor.read()
        let uptime = ProcessInfo.processInfo.systemUptime

        return SystemMetrics(
            timestamp: .now,
            cpu: cpu,
            memory: memory,
            network: network,
            battery: battery,
            disk: disk,
            thermal: thermal,
            wifi: wifi,
            systemInfo: systemInfo,
            uptime: uptime
        )
    }
}

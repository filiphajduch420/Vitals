import Foundation
import SwiftUI

@MainActor
@Observable
final class AppState {

    var metrics: SystemMetrics = .empty
    var cpuHistory = MetricHistory(capacity: 60)
    var memoryHistory = MetricHistory(capacity: 60)
    var networkDownHistory = MetricHistory(capacity: 60)
    var networkUpHistory = MetricHistory(capacity: 60)
    var batteryHistory = MetricHistory(capacity: 60)
    var diskHistory = MetricHistory(capacity: 60)

    private let monitor = SystemMonitor()

    // MARK: - Menu Bar Items (granular toggles)

    var barCPUUsage: Bool = true { didSet { save(barCPUUsage, forKey: "barCPUUsage") } }
    var barCPUTemp: Bool = false { didSet { save(barCPUTemp, forKey: "barCPUTemp") } }
    var barFanRPM: Bool = false { didSet { save(barFanRPM, forKey: "barFanRPM") } }
    var barMemory: Bool = true { didSet { save(barMemory, forKey: "barMemory") } }
    var barNetworkDown: Bool = true { didSet { save(barNetworkDown, forKey: "barNetworkDown") } }
    var barNetworkUp: Bool = true { didSet { save(barNetworkUp, forKey: "barNetworkUp") } }
    var barBattery: Bool = true { didSet { save(barBattery, forKey: "barBattery") } }
    var barGPUTemp: Bool = false { didSet { save(barGPUTemp, forKey: "barGPUTemp") } }
    var barPower: Bool = false { didSet { save(barPower, forKey: "barPower") } }
    var barDisk: Bool = false { didSet { save(barDisk, forKey: "barDisk") } }

    // Backwards compat helpers for popover toggle icons
    var showCPU: Bool { barCPUUsage }
    var showMemory: Bool { barMemory }
    var showNetwork: Bool { barNetworkDown || barNetworkUp }
    var showBattery: Bool { barBattery }
    var showDisk: Bool { barDisk }

    // MARK: - Popover section visibility

    var sectionCPU: Bool = true { didSet { save(sectionCPU, forKey: "sectionCPU") } }
    var sectionMemory: Bool = true { didSet { save(sectionMemory, forKey: "sectionMemory") } }
    var sectionNetwork: Bool = true { didSet { save(sectionNetwork, forKey: "sectionNetwork") } }
    var sectionBattery: Bool = true { didSet { save(sectionBattery, forKey: "sectionBattery") } }
    var sectionDisk: Bool = true { didSet { save(sectionDisk, forKey: "sectionDisk") } }
    var sectionWiFi: Bool = true { didSet { save(sectionWiFi, forKey: "sectionWiFi") } }
    var sectionSystem: Bool = true { didSet { save(sectionSystem, forKey: "sectionSystem") } }

    var sectionOrder: [PopoverSection] = PopoverSection.allCases {
        didSet { saveSectionOrder() }
    }

    var glassOpacity: Double = 0.0 {
        didSet { save(glassOpacity, forKey: "glassOpacity") }
    }

    var glassVariant: GlassVariant = .default {
        didSet { save(glassVariant.rawValue, forKey: "glassVariant") }
    }

    /// Text scale factor: 0.8 (small) – 1.0 (default) – 1.3 (large)
    var textScale: Double = 1.0 {
        didSet { save(textScale, forKey: "textScale") }
    }

    var updateInterval: Double = 2.0 {
        didSet {
            save(updateInterval, forKey: "updateInterval")
            startMonitoring()
        }
    }

    // MARK: - Toggle helpers for popover icons

    func isShownInMenuBar(_ metric: MetricType) -> Bool {
        switch metric {
        case .cpu:     return barCPUUsage
        case .memory:  return barMemory
        case .network: return barNetworkDown || barNetworkUp
        case .battery: return barBattery
        case .disk:    return barDisk
        }
    }

    func toggleMenuBar(_ metric: MetricType) {
        switch metric {
        case .cpu:     barCPUUsage.toggle()
        case .memory:  barMemory.toggle()
        case .network: barNetworkDown.toggle(); barNetworkUp = barNetworkDown
        case .battery: barBattery.toggle()
        case .disk:    barDisk.toggle()
        }
    }

    var hasBattery: Bool {
        get async { await monitor.hasBattery }
    }

    // MARK: - Lifecycle

    init() {
        let d = UserDefaults.standard
        if !d.bool(forKey: "v4init") {
            d.set(true, forKey: "v4init")
            d.set(true, forKey: "barCPUUsage")
            d.set(false, forKey: "barCPUTemp")
            d.set(false, forKey: "barFanRPM")
            d.set(true, forKey: "barMemory")
            d.set(true, forKey: "barNetworkDown")
            d.set(true, forKey: "barNetworkUp")
            d.set(true, forKey: "barBattery")
            d.set(false, forKey: "barGPUTemp")
            d.set(false, forKey: "barPower")
            d.set(false, forKey: "barDisk")
            d.set(true, forKey: "sectionCPU")
            d.set(true, forKey: "sectionMemory")
            d.set(true, forKey: "sectionNetwork")
            d.set(true, forKey: "sectionBattery")
            d.set(true, forKey: "sectionDisk")
            d.set(true, forKey: "sectionWiFi")
            d.set(true, forKey: "sectionSystem")
            d.set(2.0, forKey: "updateInterval")
        }

        barCPUUsage = d.bool(forKey: "barCPUUsage")
        barCPUTemp = d.bool(forKey: "barCPUTemp")
        barFanRPM = d.bool(forKey: "barFanRPM")
        barMemory = d.bool(forKey: "barMemory")
        barNetworkDown = d.bool(forKey: "barNetworkDown")
        barNetworkUp = d.bool(forKey: "barNetworkUp")
        barBattery = d.bool(forKey: "barBattery")
        barGPUTemp = d.bool(forKey: "barGPUTemp")
        barPower = d.bool(forKey: "barPower")
        barDisk = d.bool(forKey: "barDisk")
        sectionCPU = d.bool(forKey: "sectionCPU")
        sectionMemory = d.bool(forKey: "sectionMemory")
        sectionNetwork = d.bool(forKey: "sectionNetwork")
        sectionBattery = d.bool(forKey: "sectionBattery")
        sectionDisk = d.bool(forKey: "sectionDisk")
        sectionWiFi = d.bool(forKey: "sectionWiFi")
        sectionSystem = d.object(forKey: "sectionSystem") == nil ? true : d.bool(forKey: "sectionSystem")
        sectionOrder = loadSectionOrder()
        glassOpacity = d.object(forKey: "glassOpacity") != nil ? d.double(forKey: "glassOpacity") : 0.0
        glassVariant = GlassVariant(rawValue: d.integer(forKey: "glassVariant")) ?? .default
        let savedScale = d.double(forKey: "textScale")
        textScale = savedScale > 0 ? savedScale : 1.0
        let interval = d.double(forKey: "updateInterval")
        updateInterval = interval > 0 ? interval : 2.0
    }

    func startMonitoring() {
        Task {
            await monitor.startPolling(interval: updateInterval) { [weak self] newMetrics in
                self?.updateMetrics(newMetrics)
            }
        }
    }

    func stopMonitoring() {
        Task { await monitor.stopPolling() }
    }

    // MARK: - Private

    private func updateMetrics(_ newMetrics: SystemMetrics) {
        metrics = newMetrics
        let now = newMetrics.timestamp

        cpuHistory.append(newMetrics.cpu.totalUsage, at: now)
        memoryHistory.append(newMetrics.memory.usageRatio, at: now)
        diskHistory.append(newMetrics.disk.usageRatio, at: now)

        let maxSpeed: Double = 100 * 1024 * 1024
        networkDownHistory.append(
            min(Double(newMetrics.network.downloadSpeed) / maxSpeed, 1.0), at: now
        )
        networkUpHistory.append(
            min(Double(newMetrics.network.uploadSpeed) / maxSpeed, 1.0), at: now
        )

        if let battery = newMetrics.battery {
            batteryHistory.append(Double(battery.percentage) / 100.0, at: now)
        }

        DataSharingManager.writeMetrics(newMetrics)
        DataSharingManager.refreshWidgetsIfNeeded()
    }

    func isSectionVisible(_ section: PopoverSection) -> Bool {
        switch section {
        case .system:  return sectionSystem
        case .cpu:     return sectionCPU
        case .memory:  return sectionMemory
        case .network: return sectionNetwork
        case .battery: return sectionBattery && metrics.battery != nil
        case .disk:    return sectionDisk
        case .wifi:    return sectionWiFi
        }
    }

    private func save(_ value: Bool, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    private func save(_ value: Double, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    private func save(_ value: Int, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    private func saveSectionOrder() {
        let raw = sectionOrder.map(\.rawValue)
        UserDefaults.standard.set(raw, forKey: "sectionOrder")
    }
    private func loadSectionOrder() -> [PopoverSection] {
        guard let raw = UserDefaults.standard.stringArray(forKey: "sectionOrder") else {
            return PopoverSection.allCases
        }
        var result = raw.compactMap { PopoverSection(rawValue: $0) }
        // Ensure any new sections are appended
        for section in PopoverSection.allCases where !result.contains(section) {
            result.append(section)
        }
        return result
    }
}

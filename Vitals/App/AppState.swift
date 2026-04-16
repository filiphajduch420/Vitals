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
    let powerMonitor = PowerStateMonitor()
    private var lastWidgetRefresh: Date = .distantPast

    // MARK: - Menu Bar Items (granular toggles)

    var barCPUUsage: Bool = true { didSet { save(barCPUUsage, forKey: "barCPUUsage") } }
    var barCPUTemp: Bool = false { didSet { save(barCPUTemp, forKey: "barCPUTemp") } }
    var barFanRPM: Bool = false { didSet { save(barFanRPM, forKey: "barFanRPM") } }
    var barMemory: Bool = true { didSet { save(barMemory, forKey: "barMemory") } }
    var barNetworkDown: Bool = true { didSet { save(barNetworkDown, forKey: "barNetworkDown") } }
    var barNetworkUp: Bool = true { didSet { save(barNetworkUp, forKey: "barNetworkUp") } }
    var barBattery: Bool = true { didSet { save(barBattery, forKey: "barBattery") } }
    var barGPU: Bool = false { didSet { save(barGPU, forKey: "barGPU") } }
    var barPower: Bool = false { didSet { save(barPower, forKey: "barPower") } }
    var barDisk: Bool = false { didSet { save(barDisk, forKey: "barDisk") } }
    var barIP: Bool = false { didSet { save(barIP, forKey: "barIP") } }
    var barBatteryTime: Bool = false { didSet { save(barBatteryTime, forKey: "barBatteryTime") } }

    var menuBarOrder: [MenuBarItem] = MenuBarItem.allCases {
        didSet { saveMenuBarOrder() }
    }

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
    var sectionGPU: Bool = true { didSet { save(sectionGPU, forKey: "sectionGPU") } }
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

    /// Text color brightness: 0.0 (black) – 1.0 (white)
    var textColorBrightness: Double = 0.8 {
        didSet { save(textColorBrightness, forKey: "textColorBrightness") }
    }

    var updateInterval: Double = 2.0 {
        didSet {
            save(updateInterval, forKey: "updateInterval")
            startMonitoring()
        }
    }

    var batterySavingInterval: Double = 5.0 {
        didSet {
            save(batterySavingInterval, forKey: "batterySavingInterval")
            if powerMonitor.isOnBattery { startMonitoring() }
        }
    }

    /// The actual polling interval based on power state.
    var effectiveInterval: Double {
        powerMonitor.isOnBattery ? batterySavingInterval : updateInterval
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
            d.set(false, forKey: "barNetworkDown")
            d.set(false, forKey: "barNetworkUp")
            d.set(false, forKey: "barBattery")
            d.set(false, forKey: "barBatteryTime")
            d.set(false, forKey: "barPower")
            d.set(false, forKey: "barDisk")
            d.set(false, forKey: "barGPU")
            d.set(false, forKey: "barIP")
            d.set(true, forKey: "sectionCPU")
            d.set(true, forKey: "sectionGPU")
            d.set(true, forKey: "sectionMemory")
            d.set(true, forKey: "sectionBattery")
            d.set(true, forKey: "sectionSystem")
            d.set(false, forKey: "sectionDisk")
            d.set(false, forKey: "sectionWiFi")
            d.set(false, forKey: "sectionNetwork")
            d.set(0.2, forKey: "glassOpacity")
            d.set(2.0, forKey: "updateInterval")
            d.set(5.0, forKey: "batterySavingInterval")
        }

        barCPUUsage = d.bool(forKey: "barCPUUsage")
        barCPUTemp = d.bool(forKey: "barCPUTemp")
        barFanRPM = d.bool(forKey: "barFanRPM")
        barMemory = d.bool(forKey: "barMemory")
        barNetworkDown = d.bool(forKey: "barNetworkDown")
        barNetworkUp = d.bool(forKey: "barNetworkUp")
        barBattery = d.bool(forKey: "barBattery")
        barGPU = d.bool(forKey: "barGPU")
        barPower = d.bool(forKey: "barPower")
        barDisk = d.bool(forKey: "barDisk")
        barIP = d.bool(forKey: "barIP")
        barBatteryTime = d.bool(forKey: "barBatteryTime")
        menuBarOrder = loadMenuBarOrder()
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
        let savedBrightness = d.object(forKey: "textColorBrightness") != nil ? d.double(forKey: "textColorBrightness") : 0.8
        textColorBrightness = savedBrightness
        let interval = d.double(forKey: "updateInterval")
        updateInterval = interval > 0 ? interval : 2.0
        let savedBSI = d.double(forKey: "batterySavingInterval")
        batterySavingInterval = savedBSI > 0 ? savedBSI : 5.0

        // React to power state changes (AC ↔ Battery)
        powerMonitor.onStateChanged = { [weak self] in
            self?.startMonitoring()
        }
    }

    func startMonitoring() {
        let interval = effectiveInterval
        let saving = powerMonitor.isOnBattery
        Task {
            await monitor.setBatterySaving(saving)
            await monitor.startPolling(interval: interval) { [weak self] newMetrics in
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

        let maxSpeed: Double = 10 * 1024 * 1024 * 1024
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
        throttledWidgetRefresh()
    }

    private func throttledWidgetRefresh() {
        let now = Date()
        // Refresh widgets every 30s — free when app is running, budget-counted otherwise
        guard now.timeIntervalSince(lastWidgetRefresh) >= 30 else { return }
        lastWidgetRefresh = now
        DataSharingManager.refreshWidgetsIfNeeded()
    }

    func isSectionVisible(_ section: PopoverSection) -> Bool {
        switch section {
        case .system:  return sectionSystem
        case .cpu:     return sectionCPU
        case .gpu:     return sectionGPU
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
    func isMenuBarItemEnabled(_ item: MenuBarItem) -> Bool {
        switch item {
        case .cpuUsage:    return barCPUUsage
        case .cpuTemp:     return barCPUTemp
        case .fanRPM:      return barFanRPM
        case .gpu:         return barGPU
        case .power:       return barPower
        case .memory:      return barMemory
        case .networkDown: return barNetworkDown
        case .networkUp:   return barNetworkUp
        case .battery:     return barBattery
        case .batteryTime: return barBatteryTime
        case .disk:        return barDisk
        case .ip:          return barIP
        }
    }

    func menuBarBinding(for item: MenuBarItem) -> ReferenceWritableKeyPath<AppState, Bool> {
        switch item {
        case .cpuUsage:    return \.barCPUUsage
        case .cpuTemp:     return \.barCPUTemp
        case .fanRPM:      return \.barFanRPM
        case .gpu:         return \.barGPU
        case .power:       return \.barPower
        case .memory:      return \.barMemory
        case .networkDown: return \.barNetworkDown
        case .networkUp:   return \.barNetworkUp
        case .battery:     return \.barBattery
        case .batteryTime: return \.barBatteryTime
        case .disk:        return \.barDisk
        case .ip:          return \.barIP
        }
    }

    private func saveMenuBarOrder() {
        let raw = menuBarOrder.map(\.rawValue)
        UserDefaults.standard.set(raw, forKey: "menuBarOrder")
    }

    private func loadMenuBarOrder() -> [MenuBarItem] {
        guard let raw = UserDefaults.standard.stringArray(forKey: "menuBarOrder") else {
            return MenuBarItem.allCases
        }
        var result = raw.compactMap { MenuBarItem(rawValue: $0) }
        for item in MenuBarItem.allCases where !result.contains(item) {
            result.append(item)
        }
        return result
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

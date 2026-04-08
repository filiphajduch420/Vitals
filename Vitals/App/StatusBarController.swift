import SwiftUI
import AppKit

@MainActor
final class StatusBarController {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var appState: AppState
    private var globalMonitor: Any?

    init(appState: AppState) {
        self.appState = appState
        setupStatusItem()
        setupPanel()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(togglePanel(_:))
            button.target = self
            updateLabel()
        }

        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateLabel() }
        }
    }

    private func updateLabel() {
        guard let button = statusItem.button else { return }
        let m = appState.metrics
        let th = m.thermal

        let attachment = NSMutableAttributedString()
        let fontSize: CGFloat = 12
        let iconSize: CGFloat = 12
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .baselineOffset: 0]

        func addIcon(_ name: String) {
            if let img = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .semibold)
                let configured = img.withSymbolConfiguration(config) ?? img
                let a = NSTextAttachment()
                a.image = configured
                attachment.append(NSAttributedString(attachment: a))
                attachment.append(NSAttributedString(string: " ", attributes: attrs))
            }
        }

        func addText(_ text: String) {
            attachment.append(NSAttributedString(string: text, attributes: attrs))
        }

        func addSpacer() {
            attachment.append(NSAttributedString(string: "  ", attributes: attrs))
        }

        // CPU Usage
        if appState.barCPUUsage {
            addIcon("cpu.fill")
            addText("\(Int(m.cpu.totalUsage * 100))%")
            addSpacer()
        }

        // CPU Temperature
        if appState.barCPUTemp, let temp = th.cpuTemperature {
            addIcon("thermometer.medium")
            addText("\(Int(temp))°")
            addSpacer()
        }

        // Fan RPM
        if appState.barFanRPM, let rpm = th.fanRPM {
            addIcon("fan.fill")
            addText(rpm > 0 ? "\(rpm)" : "Off")
            addSpacer()
        }

        // GPU Temperature
        if appState.barGPUTemp, let gpu = th.gpuTemperature {
            addIcon("rectangle.and.text.magnifyingglass")
            addText("\(Int(gpu))°")
            addSpacer()
        }

        // System Power
        if appState.barPower, let watts = th.systemPower {
            addIcon("bolt.fill")
            addText(String(format: "%.0fW", watts))
            addSpacer()
        }

        // Memory
        if appState.barMemory {
            addIcon("memorychip.fill")
            addText(Formatters.formatBytes(m.memory.used))
            addSpacer()
        }

        // Network Down
        if appState.barNetworkDown {
            addIcon("arrow.down")
            addText(Formatters.formatBytesPerSec(m.network.downloadSpeed))
            addSpacer()
        }

        // Network Up
        if appState.barNetworkUp {
            addIcon("arrow.up")
            addText(Formatters.formatBytesPerSec(m.network.uploadSpeed))
            addSpacer()
        }

        // Battery
        if appState.barBattery, let bat = m.battery {
            let icon = bat.isCharging ? "battery.100percent.bolt" : "battery.75percent"
            addIcon(icon)
            addText("\(bat.percentage)%")
            addSpacer()
        }

        // Disk
        if appState.barDisk {
            addIcon("internaldrive.fill")
            addText("\(Int(m.disk.usageRatio * 100))%")
        }

        button.attributedTitle = attachment
    }

    // MARK: - Transparent Glass Panel

    private func setupPanel() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 290, height: 500),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow

        let rootView = PopoverView()
            .environment(appState)

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear

        panel.contentView = hostingView
    }

    @objc private func togglePanel(_ sender: Any?) {
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let button = statusItem.button else { return }
        let buttonFrame = button.window?.convertToScreen(button.frame) ?? .zero

        // Cap height to available screen space (menu bar to dock)
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let maxHeight = buttonFrame.minY - screen.visibleFrame.origin.y - 16

        panel.contentView?.invalidateIntrinsicContentSize()
        let contentSize = panel.contentView?.fittingSize ?? NSSize(width: 290, height: 500)
        let panelWidth = contentSize.width
        let panelHeight = min(contentSize.height, maxHeight)

        let x = buttonFrame.midX - panelWidth / 2
        let y = buttonFrame.minY - 8 - panelHeight

        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        panel.orderFrontRegardless()

        // Close on outside click
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hidePanel()
        }
    }

    private func hidePanel() {
        panel.orderOut(nil)
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }
}

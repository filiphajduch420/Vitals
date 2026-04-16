import SwiftUI
import AppKit

@MainActor
final class StatusBarController {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var appState: AppState
    private var globalMonitor: Any?
    private var labelUpdateTask: Task<Void, Never>?

    init(appState: AppState) {
        self.appState = appState
        setupStatusItem()
        setupPanel()
    }

    nonisolated deinit {
        // Note: cleanup happens via hidePanel() during normal usage.
        // globalMonitor and labelUpdateTask are cleaned up by ARC.
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(togglePanel(_:))
            button.target = self
            updateLabel()
        }

        startLabelUpdates()
    }

    private func startLabelUpdates() {
        labelUpdateTask?.cancel()
        labelUpdateTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.updateLabel()
                try? await Task.sleep(for: .seconds(self.appState.effectiveInterval))
            }
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

        for item in appState.menuBarOrder {
            guard appState.isMenuBarItemEnabled(item) else { continue }
            switch item {
            case .cpuUsage:
                addIcon("cpu.fill")
                addText("\(Int(m.cpu.totalUsage * 100))%")
            case .cpuTemp:
                guard let temp = th.cpuTemperature else { continue }
                addIcon("thermometer.medium")
                addText("\(Int(temp))°")
            case .fanRPM:
                guard let rpm = th.fanRPM else { continue }
                addIcon("fan.fill")
                addText(rpm > 0 ? "\(rpm)" : "Off")
            case .gpu:
                guard let util = m.gpu.utilization else { continue }
                addIcon("display")
                addText("\(Int(util * 100))%")
            case .power:
                guard let watts = th.systemPower else { continue }
                addIcon("bolt.fill")
                addText(String(format: "%.0fW", watts))
            case .memory:
                addIcon("memorychip.fill")
                addText(Formatters.formatBytes(m.memory.used))
            case .networkDown:
                addIcon("arrow.down")
                addText(Formatters.formatBytesPerSec(m.network.downloadSpeed))
            case .networkUp:
                addIcon("arrow.up")
                addText(Formatters.formatBytesPerSec(m.network.uploadSpeed))
            case .battery:
                guard let bat = m.battery else { continue }
                addIcon(bat.isCharging ? "battery.100percent.bolt" : "battery.75percent")
                addText("\(bat.percentage)%")
            case .batteryTime:
                guard let bat = m.battery else { continue }
                addIcon("clock")
                if let time = bat.timeRemaining, time > 0 {
                    addText(Formatters.formatDuration(time))
                } else if bat.isPluggedIn {
                    addText("\u{221E}")
                } else {
                    continue
                }
            case .disk:
                addIcon("internaldrive.fill")
                addText("\(Int(m.disk.usageRatio * 100))%")
            case .ip:
                guard let ip = m.wifi.localIP else { continue }
                addIcon("network")
                addText(ip)
            }
            addSpacer()
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

        // Always use full available height — panel is transparent so empty space is invisible
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let panelWidth: CGFloat = 290
        let panelHeight = buttonFrame.minY - screen.visibleFrame.origin.y - 16

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

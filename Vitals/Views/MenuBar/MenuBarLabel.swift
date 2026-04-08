import SwiftUI

struct MenuBarLabel: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 6) {
            if appState.showCPU {
                CompactMetricView(
                    icon: "cpu.fill",
                    value: formatPercent(appState.metrics.cpu.totalUsage)
                )
            }

            if appState.showMemory {
                CompactMetricView(
                    icon: "memorychip.fill",
                    value: Formatters.formatBytes(appState.metrics.memory.used)
                )
            }

            if appState.showNetwork {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 8, weight: .bold))
                    Text(Formatters.formatBytesPerSec(appState.metrics.network.downloadSpeed))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                    Image(systemName: "arrow.up")
                        .font(.system(size: 8, weight: .bold))
                    Text(Formatters.formatBytesPerSec(appState.metrics.network.uploadSpeed))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
            }

            if appState.showBattery, let battery = appState.metrics.battery {
                CompactMetricView(
                    icon: batteryIcon(for: battery),
                    value: "\(battery.percentage)%"
                )
            }

            if appState.showDisk {
                CompactMetricView(
                    icon: "internaldrive.fill",
                    value: formatPercent(appState.metrics.disk.usageRatio)
                )
            }
        }
        .onAppear {
            appState.startMonitoring()
        }
    }

    private func formatPercent(_ value: Double) -> String {
        "\(Int(value * 100))%"
    }

    private func batteryIcon(for battery: BatteryMetrics) -> String {
        if battery.isCharging {
            return "battery.100percent.bolt"
        }
        switch battery.percentage {
        case 0..<13:  return "battery.0percent"
        case 13..<38: return "battery.25percent"
        case 38..<63: return "battery.50percent"
        case 63..<88: return "battery.75percent"
        default:      return "battery.100percent"
        }
    }
}

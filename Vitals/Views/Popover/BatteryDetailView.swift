import SwiftUI

struct BatteryDetailView: View {

    @Environment(AppState.self) private var appState

    private var battery: BatteryMetrics? { appState.metrics.battery }

    var body: some View {
        if let bat = battery {
            MetricCardView(
                metricType: .battery,
                icon: batteryIcon(bat),
                title: "Battery",
                value: "\(bat.percentage)%",
                color: batteryColor(bat),
                history: appState.batteryHistory
            ) {
                HStack(spacing: 12) {
                    miniLabel("Status", bat.isCharging ? "Charging" : (bat.isPluggedIn ? "Plugged In" : "On Battery"))

                    if let time = bat.timeRemaining {
                        miniLabel(
                            bat.isCharging ? "Full In" : "Remaining",
                            Formatters.formatDuration(time)
                        )
                    }

                    if let temp = appState.metrics.thermal.batteryTemperature {
                        HStack(spacing: 3) {
                            Image(systemName: "thermometer.medium")
                            Text(String(format: "%.1f°C", temp))
                                .fontWeight(.medium)
                                .monospacedDigit()
                        }
                    }
                }
                .scaledFont(10)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func batteryIcon(_ bat: BatteryMetrics) -> String {
        if bat.isCharging { return "battery.100percent.bolt" }
        switch bat.percentage {
        case 0..<13:  return "battery.0percent"
        case 13..<38: return "battery.25percent"
        case 38..<63: return "battery.50percent"
        case 63..<88: return "battery.75percent"
        default:      return "battery.100percent"
        }
    }

    private func batteryColor(_ bat: BatteryMetrics) -> Color {
        if bat.isCharging { return .green }
        switch bat.percentage {
        case 0..<10:  return .red
        case 10..<20: return .orange
        default:      return .green
        }
    }

    private func miniLabel(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
        }
    }
}

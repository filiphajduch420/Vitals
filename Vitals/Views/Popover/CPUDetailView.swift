import SwiftUI

struct CPUDetailView: View {

    @Environment(AppState.self) private var appState

    private var cpu: CPUMetrics { appState.metrics.cpu }
    private var th: ThermalMetrics { appState.metrics.thermal }

    var body: some View {
        MetricCardView(
            metricType: .cpu,
            icon: "cpu.fill",
            title: "CPU",
            value: "\(Int(cpu.totalUsage * 100))%",
            color: usageColor(cpu.totalUsage),
            history: appState.cpuHistory
        ) {
            VStack(spacing: 5) {
                HStack(spacing: 10) {
                    miniStat("User", "\(Int(cpu.userUsage * 100))%")
                    miniStat("System", "\(Int(cpu.systemUsage * 100))%")
                    miniStat("Idle", "\(Int(cpu.idleUsage * 100))%")
                    miniStat("Cores", "\(cpu.activeCores)/\(cpu.totalCores)")
                    Spacer()
                }

                HStack(spacing: 10) {
                    if let temp = th.cpuTemperature {
                        iconStat("thermometer.medium", "\(Int(temp))°C")
                    }
                    if let rpm = th.fanRPM {
                        iconStat("fan.fill", rpm > 0 ? "\(rpm) RPM" : "Off")
                    }
                    if let watts = th.systemPower {
                        iconStat("bolt.fill", String(format: "%.1fW", watts))
                    }
                    Spacer()
                }
            }
            .scaledFont(10)
            .foregroundStyle(.secondary)
        }
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label).foregroundStyle(.secondary)
            Text(value).fontWeight(.medium).monospacedDigit()
        }
    }

    private func iconStat(_ icon: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
        }
    }
}

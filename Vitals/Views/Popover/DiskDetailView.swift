import SwiftUI

struct DiskDetailView: View {

    @Environment(AppState.self) private var appState

    private var disk: DiskMetrics { appState.metrics.disk }

    var body: some View {
        MetricCardView(
            metricType: .disk,
            icon: "internaldrive.fill",
            title: "Disk",
            value: "\(Formatters.formatBytes(disk.usedSpace)) / \(Formatters.formatBytes(disk.totalSpace))",
            color: usageColor(disk.usageRatio),
            history: appState.diskHistory
        ) {
            UsageBarView(value: disk.usageRatio, color: usageColor(disk.usageRatio))

            HStack(spacing: 12) {
                miniLabel("Free", Formatters.formatBytes(disk.freeSpace))

                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.doc.fill")
                    Text(Formatters.formatBytesPerSec(disk.readSpeed))
                        .fontWeight(.medium)
                        .monospacedDigit()
                }

                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.doc.fill")
                    Text(Formatters.formatBytesPerSec(disk.writeSpeed))
                        .fontWeight(.medium)
                        .monospacedDigit()
                }

                if let ssdTemp = appState.metrics.thermal.ssdTemperature {
                    HStack(spacing: 3) {
                        Image(systemName: "thermometer.medium")
                        Text(String(format: "%.0f°C", ssdTemp))
                            .fontWeight(.medium)
                            .monospacedDigit()
                    }
                }
            }
            .scaledFont(10)
            .adaptiveSecondary()
        }
    }

    private func miniLabel(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label).adaptiveSecondary()
            Text(value).fontWeight(.medium).monospacedDigit()
        }
    }
}

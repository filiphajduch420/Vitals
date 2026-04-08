import SwiftUI

struct MemoryDetailView: View {

    @Environment(AppState.self) private var appState

    private var mem: MemoryMetrics { appState.metrics.memory }

    var body: some View {
        MetricCardView(
            metricType: .memory,
            icon: "memorychip.fill",
            title: "Memory",
            value: "\(Formatters.formatBytes(mem.used)) / \(Formatters.formatBytes(mem.total))",
            color: usageColor(mem.usageRatio),
            history: appState.memoryHistory
        ) {
            VStack(alignment: .leading, spacing: 4) {
                UsageBarView(value: mem.usageRatio, color: usageColor(mem.usageRatio))

                HStack(spacing: 12) {
                    miniLabel("Active", Formatters.formatBytes(mem.active))
                    miniLabel("Wired", Formatters.formatBytes(mem.wired))
                    miniLabel("Compressed", Formatters.formatBytes(mem.compressed))
                }
                .scaledFont(10)
                .foregroundStyle(.secondary)
            }
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

import SwiftUI

struct NetworkDetailView: View {

    @Environment(AppState.self) private var appState

    private var net: NetworkMetrics { appState.metrics.network }

    var body: some View {
        GlassMorphicCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "network")
                        .scaledFont(13, weight: .semibold)
                        .foregroundStyle(.blue)
                    Text("Network")
                        .scaledFont(12, weight: .semibold, design: .rounded)
                    Spacer()
                }

                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.down")
                            .scaledFont(9, weight: .bold)
                            .foregroundStyle(.green)
                        Text(Formatters.formatBytesPerSec(net.downloadSpeed))
                            .scaledFont(11, weight: .bold, design: .monospaced)
                            .foregroundStyle(.green)
                        Spacer()
                        Image(systemName: "arrow.up")
                            .scaledFont(9, weight: .bold)
                            .foregroundStyle(.orange)
                        Text(Formatters.formatBytesPerSec(net.uploadSpeed))
                            .scaledFont(11, weight: .bold, design: .monospaced)
                            .foregroundStyle(.orange)
                    }

                    HStack(spacing: 4) {
                        SparklineView(history: appState.networkDownHistory, color: .green)
                            .frame(height: 22)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        SparklineView(history: appState.networkUpHistory, color: .orange)
                            .frame(height: 22)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                HStack(spacing: 16) {
                    miniLabel("Total Down", Formatters.formatBytes(net.totalDownloaded))
                    miniLabel("Total Up", Formatters.formatBytes(net.totalUploaded))
                }
                .scaledFont(10)
                .adaptiveSecondary()
            }
        }
    }

    private func miniLabel(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .adaptiveSecondary()
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
        }
    }
}

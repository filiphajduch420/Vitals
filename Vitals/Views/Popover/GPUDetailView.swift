import SwiftUI

struct GPUDetailView: View {

    @Environment(AppState.self) private var appState

    private var gpu: GPUMetrics { appState.metrics.gpu }

    var body: some View {
        GlassMorphicCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "display")
                        .scaledFont(13, weight: .semibold)
                        .foregroundStyle(.purple)
                    Text("GPU")
                        .scaledFont(12, weight: .semibold, design: .rounded)
                    Spacer()
                    if let util = gpu.utilization {
                        Text("\(Int(util * 100))%")
                            .scaledFont(12, weight: .bold, design: .monospaced)
                            .foregroundStyle(usageColor(util))
                    }
                }

                if let util = gpu.utilization {
                    UsageBarView(value: util, color: usageColor(util))
                }

                HStack(spacing: 12) {
                    if let util = gpu.utilization {
                        iconStat("gauge.high", "Load \(Int(util * 100))%")
                    }
                    if let used = gpu.vramUsed {
                        iconStat("memorychip", "VRAM \(Formatters.formatBytes(used))")
                    }
                    if let temp = gpu.temperature {
                        iconStat("thermometer.medium", "\(Int(temp))°C")
                    }
                }
                .scaledFont(10)
                .adaptiveSecondary()
            }
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

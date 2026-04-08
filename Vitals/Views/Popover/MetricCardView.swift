import SwiftUI

struct MetricCardView<Content: View>: View {

    let metricType: MetricType
    let icon: String
    let title: String
    let value: String
    let color: Color
    let history: MetricHistory
    @ViewBuilder let detail: () -> Content

    init(
        metricType: MetricType,
        icon: String,
        title: String,
        value: String,
        color: Color = .accentColor,
        history: MetricHistory,
        @ViewBuilder detail: @escaping () -> Content = { EmptyView() }
    ) {
        self.metricType = metricType
        self.icon = icon
        self.title = title
        self.value = value
        self.color = color
        self.history = history
        self.detail = detail
    }

    var body: some View {
        GlassMorphicCard {
            VStack(alignment: .leading, spacing: 6) {
                // Title row
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .scaledFont(13, weight: .semibold)
                        .foregroundStyle(color)
                    Text(title)
                        .scaledFont(12, weight: .semibold, design: .rounded)
                    Spacer()
                    Text(value)
                        .scaledFont(12, weight: .bold, design: .monospaced)
                        .foregroundStyle(color)
                }

                // Sparkline
                SparklineView(history: history, color: color)
                    .frame(height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                // Optional detail content
                detail()
            }
        }
    }
}

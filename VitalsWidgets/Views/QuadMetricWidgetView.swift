import SwiftUI
import WidgetKit

struct QuadMetricWidget: Widget {
    let kind = "QuadMetricWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: QuadMetricIntent.self,
            provider: QuadMetricProvider()
        ) { entry in
            QuadMetricWidgetView(entry: entry)
                .containerBackground(.ultraThinMaterial, for: .widget)
        }
        .configurationDisplayName("Quad Metrics")
        .description("Display four system metrics in a grid.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct QuadMetricWidgetView: View {
    let entry: QuadMetricEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        let gaugeSize: CGFloat = family == .systemLarge ? 56 : 44

        if family == .systemLarge {
            VStack(spacing: 16) {
                HStack(spacing: 32) {
                    MetricGaugeWidget(choice: entry.choice1, metrics: entry.metrics, size: gaugeSize)
                    MetricGaugeWidget(choice: entry.choice2, metrics: entry.metrics, size: gaugeSize)
                }
                HStack(spacing: 32) {
                    MetricGaugeWidget(choice: entry.choice3, metrics: entry.metrics, size: gaugeSize)
                    MetricGaugeWidget(choice: entry.choice4, metrics: entry.metrics, size: gaugeSize)
                }
            }
        } else {
            HStack(spacing: 16) {
                MetricGaugeWidget(choice: entry.choice1, metrics: entry.metrics, size: gaugeSize)
                MetricGaugeWidget(choice: entry.choice2, metrics: entry.metrics, size: gaugeSize)
                MetricGaugeWidget(choice: entry.choice3, metrics: entry.metrics, size: gaugeSize)
                MetricGaugeWidget(choice: entry.choice4, metrics: entry.metrics, size: gaugeSize)
            }
        }
    }
}

import SwiftUI
import WidgetKit

struct DualMetricWidget: Widget {
    let kind = "DualMetricWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: DualMetricIntent.self,
            provider: DualMetricProvider()
        ) { entry in
            DualMetricWidgetView(entry: entry)
                .containerBackground(.ultraThinMaterial, for: .widget)
        }
        .configurationDisplayName("Dual Metrics")
        .description("Display two system metrics side by side.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DualMetricWidgetView: View {
    let entry: DualMetricEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        HStack(spacing: family == .systemSmall ? 12 : 32) {
            MetricGaugeWidget(
                choice: entry.choice1,
                metrics: entry.metrics,
                size: family == .systemSmall ? 48 : 60
            )
            MetricGaugeWidget(
                choice: entry.choice2,
                metrics: entry.metrics,
                size: family == .systemSmall ? 48 : 60
            )
        }
    }
}

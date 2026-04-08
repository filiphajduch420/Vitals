import SwiftUI
import WidgetKit

struct SingleMetricWidget: Widget {
    let kind = "SingleMetricWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SingleMetricIntent.self,
            provider: SingleMetricProvider()
        ) { entry in
            SingleMetricWidgetView(entry: entry)
                .containerBackground(.ultraThinMaterial, for: .widget)
        }
        .configurationDisplayName("Single Metric")
        .description("Display one system metric.")
        .supportedFamilies([.systemSmall])
    }
}

struct SingleMetricWidgetView: View {
    let entry: SingleMetricEntry

    var body: some View {
        MetricGaugeWidget(
            choice: entry.choice,
            metrics: entry.metrics,
            size: 64
        )
    }
}

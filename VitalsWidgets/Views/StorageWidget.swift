import SwiftUI
import WidgetKit

struct StorageWidget: Widget {
    let kind = "StorageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VitalsTimelineProvider()) { entry in
            StorageWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetGradientBackground(accentColor: usageColor(entry.metrics.disk.usageRatio))
                }
        }
        .configurationDisplayName("Storage")
        .description("Disk usage and free space.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct StorageWidgetView: View {
    let entry: VitalsEntry
    @Environment(\.widgetFamily) var family

    private var disk: DiskMetrics { entry.metrics.disk }
    private var percent: Int { Int(disk.usageRatio * 100) }
    private var color: Color { usageColor(disk.usageRatio) }

    var body: some View {
        switch family {
        case .systemMedium: mediumBody
        default: smallBody
        }
    }

    private var smallBody: some View {
        VStack(spacing: 6) {
            WidgetHeader(icon: "internaldrive.fill", title: "STORAGE")

            ZStack {
                DonutRing(ratio: disk.usageRatio, color: color)
                    .widgetAccentable()

                VStack(spacing: -2) {
                    BigPercent(percent: percent)
                    Text("used")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .kerning(0.6)
                }
            }
            .frame(maxHeight: .infinity)

            Text("\(Formatters.formatBytes(disk.freeSpace)) free")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var mediumBody: some View {
        HStack(spacing: 18) {
            ZStack {
                DonutRing(ratio: disk.usageRatio, color: color)
                    .widgetAccentable()
                BigPercent(percent: percent, numberSize: 28, symbolSize: 14)
            }
            .frame(width: 88, height: 88)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Storage")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    WidgetStatRow(label: "Used", value: Formatters.formatBytes(disk.usedSpace), valueColor: color)
                    WidgetStatRow(label: "Free", value: Formatters.formatBytes(disk.freeSpace))
                    WidgetStatRow(label: "Total", value: Formatters.formatBytes(disk.totalSpace))
                }
            }
            Spacer(minLength: 0)
        }
    }
}

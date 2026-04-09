import SwiftUI
import WidgetKit

struct StorageWidget: Widget {
    let kind = "StorageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VitalsTimelineProvider()) { entry in
            StorageWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
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

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 10) {
            HStack(spacing: 6) {
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(usageColor(disk.usageRatio))
                Text("Storage")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
                Text("\(Int(disk.usageRatio * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(usageColor(disk.usageRatio))
            }

            // Usage bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(usageColor(disk.usageRatio).opacity(0.15))
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(usageColor(disk.usageRatio))
                        .frame(width: geo.size.width * disk.usageRatio)
                }
            }
            .frame(height: 8)

            HStack {
                statLabel("Used", Formatters.formatBytes(disk.usedSpace))
                Spacer()
                statLabel("Free", Formatters.formatBytes(disk.freeSpace))
                if family == .systemMedium {
                    Spacer()
                    statLabel("Total", Formatters.formatBytes(disk.totalSpace))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statLabel(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
    }
}

import SwiftUI
import WidgetKit

struct SystemInfoWidget: Widget {
    let kind = "SystemInfoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SystemInfoProvider()) { entry in
            SystemInfoWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetGradientBackground(accentColor: systemInfoAccent)
                }
        }
        .configurationDisplayName("System Info")
        .description("Uptime, macOS version, and Mac model.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SystemInfoWidgetView: View {
    let entry: SystemInfoEntry
    @Environment(\.widgetFamily) var family

    // macOS version without the "macOS " prefix, for compact stat rows.
    private var osShort: String {
        entry.osVersion.replacingOccurrences(of: "macOS ", with: "")
    }

    private var bootedString: String {
        entry.bootDate.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    var body: some View {
        switch family {
        case .systemMedium: mediumBody
        default: smallBody
        }
    }

    private var smallBody: some View {
        VStack(spacing: 6) {
            WidgetHeader(icon: "clock.fill", title: "UPTIME")

            VStack(spacing: 2) {
                // Relative style ticks itself on the widget side — no timeline
                // refresh needed to keep the uptime live.
                Text(entry.bootDate, style: .relative)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .widgetAccentable()
                Text("since last boot")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .kerning(0.6)
            }
            .frame(maxHeight: .infinity)

            VStack(spacing: 2) {
                Text(entry.osVersion)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(entry.modelName)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    private var mediumBody: some View {
        HStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(systemInfoAccent)
                    .widgetAccentable()
                // Relative style ticks itself on the widget side — keep it
                // as-is so the uptime stays live without a timeline refresh.
                Text(entry.bootDate, style: .relative)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                Text("uptime")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .kerning(0.6)
            }
            .frame(width: 88)

            VStack(alignment: .leading, spacing: 8) {
                WidgetMediumHeader(icon: "desktopcomputer", title: "System")

                VStack(alignment: .leading, spacing: 5) {
                    WidgetStatRow(label: "macOS", value: osShort, valueColor: systemInfoAccent)
                    WidgetStatRow(label: "Model", value: entry.modelName)
                    WidgetStatRow(label: "Booted", value: bootedString)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Accent

private let systemInfoAccent: Color = .blue

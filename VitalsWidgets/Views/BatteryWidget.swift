import SwiftUI
import WidgetKit

struct BatteryWidget: Widget {
    let kind = "BatteryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VitalsTimelineProvider()) { entry in
            BatteryWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetGradientBackground(accentColor: batteryAccentColor(for: entry.metrics.battery))
                }
        }
        .configurationDisplayName("Battery")
        .description("Battery level, health, and cycle count.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct BatteryWidgetView: View {
    let entry: VitalsEntry
    @Environment(\.widgetFamily) var family

    private var bat: BatteryMetrics? { entry.metrics.battery }
    private var ratio: Double { Double(bat?.percentage ?? 0) / 100.0 }
    private var color: Color { batteryAccentColor(for: bat) }

    var body: some View {
        if bat != nil {
            switch family {
            case .systemMedium: mediumBody
            default: smallBody
            }
        } else {
            noBatteryBody
        }
    }

    private var smallBody: some View {
        VStack(spacing: 6) {
            WidgetHeader(icon: headerIcon, title: "BATTERY")

            ZStack {
                DonutRing(ratio: ratio, color: color)
                    .widgetAccentable()

                VStack(spacing: -2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        BigPercent(percent: bat?.percentage ?? 0)
                        if bat?.isCharging == true {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(color)
                        }
                    }
                    Text(statusLabel)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .kerning(0.6)
                }
            }
            .frame(maxHeight: .infinity)

            Text(smallBottomLine)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var mediumBody: some View {
        HStack(spacing: 18) {
            ZStack {
                DonutRing(ratio: ratio, color: color)
                    .widgetAccentable()
                BigPercent(percent: bat?.percentage ?? 0, numberSize: 28, symbolSize: 14)
            }
            .frame(width: 88, height: 88)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: headerIcon)
                        .font(.system(size: 11, weight: .semibold))
                    Text("Battery")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    if bat?.isCharging == true {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(color)
                    }
                }
                .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    WidgetStatRow(label: "Status", value: statusLabel, valueColor: color)

                    if let health = bat?.healthPercent {
                        WidgetStatRow(label: "Health", value: "\(health)%")
                    }

                    if let cycles = bat?.cycleCount {
                        WidgetStatRow(label: "Cycles", value: "\(cycles)")
                    }

                    if let timeValue = timeRemainingValue {
                        WidgetStatRow(label: timeLabel, value: timeValue)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var noBatteryBody: some View {
        VStack(spacing: 8) {
            Image(systemName: "battery.slash")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No Battery")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Derived values

    private var headerIcon: String {
        guard let bat else { return "battery.slash" }
        if bat.isCharging { return "battery.100percent.bolt" }
        if bat.percentage >= 75 { return "battery.100percent" }
        if bat.percentage >= 50 { return "battery.75percent" }
        if bat.percentage >= 25 { return "battery.50percent" }
        return "battery.25percent"
    }

    private var statusLabel: String {
        guard let bat else { return "Battery" }
        if bat.isCharging { return "Charging" }
        if bat.isPluggedIn { return "Plugged" }
        return "Battery"
    }

    private var timeLabel: String {
        (bat?.isCharging == true) ? "Full In" : "Left"
    }

    private var timeRemainingValue: String? {
        guard let bat else { return nil }
        if let time = bat.timeRemaining, time > 0 {
            return Formatters.formatDuration(time)
        }
        if bat.isPluggedIn {
            return "\u{221E}"
        }
        return nil
    }

    private var smallBottomLine: String {
        guard let bat else { return "" }
        if let timeValue = timeRemainingValue {
            return timeValue
        }
        if let health = bat.healthPercent {
            return "Health \(health)%"
        }
        if let cycles = bat.cycleCount {
            return "\(cycles) cycles"
        }
        return "\(bat.percentage)%"
    }
}

// MARK: - Battery color

private func batteryAccentColor(for bat: BatteryMetrics?) -> Color {
    guard let bat else { return .gray }
    if bat.isCharging { return .green }
    if bat.percentage < 10 { return .red }
    if bat.percentage < 20 { return .orange }
    if bat.percentage < 50 { return .yellow }
    return .green
}

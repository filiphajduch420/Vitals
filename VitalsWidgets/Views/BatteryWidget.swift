import SwiftUI
import WidgetKit

struct BatteryWidget: Widget {
    let kind = "BatteryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VitalsTimelineProvider()) { entry in
            BatteryWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
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

    var body: some View {
        if let bat {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: bat.isCharging ? "battery.100percent.bolt" : "battery.75percent")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(batteryColor)
                    Text("Battery")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("\(bat.percentage)%")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(batteryColor)
                }

                // Usage bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(batteryColor.opacity(0.15))
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(batteryColor)
                            .frame(width: geo.size.width * Double(bat.percentage) / 100.0)
                    }
                }
                .frame(height: 8)

                HStack(spacing: family == .systemSmall ? 8 : 16) {
                    statLabel("Status", bat.isCharging ? "Charging" : (bat.isPluggedIn ? "Plugged" : "Battery"))

                    if let health = bat.healthPercent {
                        statLabel("Health", "\(health)%")
                    }

                    if let cycles = bat.cycleCount {
                        statLabel("Cycles", "\(cycles)")
                    }

                    if family == .systemMedium {
                        if let time = bat.timeRemaining, time > 0 {
                            statLabel(bat.isCharging ? "Full In" : "Left", Formatters.formatDuration(time))
                        } else if bat.isPluggedIn {
                            statLabel("Left", "\u{221E}")
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "battery.slash")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text("No Battery")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var batteryColor: Color {
        guard let bat else { return .secondary }
        if bat.isCharging { return .green }
        if bat.percentage < 10 { return .red }
        if bat.percentage < 20 { return .orange }
        return .green
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

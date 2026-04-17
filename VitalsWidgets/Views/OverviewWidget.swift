import SwiftUI
import WidgetKit

// MARK: - Widget

struct OverviewWidget: Widget {
    let kind = "OverviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VitalsTimelineProvider()) { entry in
            OverviewWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetGradientBackground(accentColor: overallAccent(for: entry))
                }
        }
        .configurationDisplayName("System Overview")
        .description("Battery, storage, and network at a glance.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Main view

struct OverviewWidgetView: View {
    let entry: VitalsEntry
    @Environment(\.widgetFamily) var family

    private var disk: DiskMetrics { entry.metrics.disk }
    private var battery: BatteryMetrics? { entry.metrics.battery }
    private var wifi: WiFiMetrics { entry.metrics.wifi }
    private var wifiConnected: Bool {
        if let ssid = wifi.ssid, !ssid.isEmpty { return true }
        return wifi.rssi != nil || wifi.localIP != nil
    }
    private var wifiName: String {
        if let ssid = wifi.ssid, !ssid.isEmpty { return ssid }
        if wifiConnected { return "Wi-Fi" }
        return "Not Connected"
    }

    private var storageColor: Color { usageColor(disk.usageRatio) }
    private var batteryColor: Color { batteryAccentColor(for: battery) }
    private var wifiColor: Color { signalColor(for: wifi) }

    var body: some View {
        switch family {
        case .systemLarge: largeBody
        default: mediumBody
        }
    }

    // MARK: Medium (~360×170)

    private var mediumBody: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 14) {
                OverviewRingCell(
                    title: "Battery",
                    ratio: batteryRatio,
                    color: batteryColor,
                    percent: battery?.percentage,
                    ringSize: 70,
                    numberSize: 22,
                    symbolSize: 12
                )
                OverviewRingCell(
                    title: "Storage",
                    ratio: disk.usageRatio,
                    color: storageColor,
                    percent: Int(disk.usageRatio * 100),
                    ringSize: 70,
                    numberSize: 22,
                    symbolSize: 12
                )
            }
            .frame(maxWidth: .infinity)

            Divider()
                .opacity(0.15)

            networkLineCompact
        }
    }

    private var networkLineCompact: some View {
        HStack(spacing: 6) {
            Image(systemName: wifiConnected ? "wifi" : "wifi.slash")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(wifiColor)

            Text(wifiName)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            if let rssi = wifi.rssi {
                Text("\(rssi) dBm")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Large (~360×360)

    private var largeBody: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 22) {
                OverviewRingCell(
                    title: "Battery",
                    subtitle: batterySubtitle,
                    ratio: batteryRatio,
                    color: batteryColor,
                    percent: battery?.percentage,
                    ringSize: 100,
                    numberSize: 30,
                    symbolSize: 14
                )
                OverviewRingCell(
                    title: "Storage",
                    subtitle: storageSubtitle,
                    ratio: disk.usageRatio,
                    color: storageColor,
                    percent: Int(disk.usageRatio * 100),
                    ringSize: 100,
                    numberSize: 30,
                    symbolSize: 14
                )
            }
            .frame(maxWidth: .infinity)

            Divider()
                .opacity(0.15)

            networkSectionLarge
        }
    }

    private var networkSectionLarge: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: wifiConnected ? "wifi" : "wifi.slash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(wifiColor)

                Text(wifiName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 4)

                SignalBars(quality: wifiConnected ? wifi.signalQuality : 0, color: wifiColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                WidgetStatRow(
                    label: "Local IP",
                    value: wifi.localIP ?? "—",
                    labelWidth: 58
                )
                WidgetStatRow(
                    label: "Public IP",
                    value: wifi.publicIP ?? "—",
                    labelWidth: 58
                )
                WidgetStatRow(
                    label: "Signal",
                    value: wifi.rssi.map { "\($0) dBm" } ?? "—",
                    labelWidth: 58,
                    valueColor: wifiColor
                )
            }
        }
    }

    // MARK: Derived

    private var batteryRatio: Double {
        guard let bat = battery else { return 0 }
        return Double(bat.percentage) / 100.0
    }

    private var batterySubtitle: String {
        guard let bat = battery else { return "Not Available" }
        if bat.isCharging { return "Charging" }
        if bat.isPluggedIn { return "Plugged In" }
        return "On Battery"
    }

    private var storageSubtitle: String {
        "\(Formatters.formatBytes(disk.freeSpace)) free"
    }
}

// MARK: - Ring Cell

private struct OverviewRingCell: View {
    let title: String
    var subtitle: String? = nil
    let ratio: Double
    let color: Color
    let percent: Int?
    let ringSize: CGFloat
    let numberSize: CGFloat
    let symbolSize: CGFloat

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                DonutRing(ratio: percent == nil ? 0 : ratio, color: color)
                    .widgetAccentable()

                if let percent {
                    BigPercent(percent: percent, numberSize: numberSize, symbolSize: symbolSize)
                } else {
                    Text("N/A")
                        .font(.system(size: numberSize * 0.7, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: ringSize, height: ringSize)

            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Signal Bars

private struct SignalBars: View {
    let quality: Double        // 0…1
    let color: Color
    private let barCount = 4

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                let threshold = Double(i + 1) / Double(barCount)
                let active = quality >= threshold - 0.001 && quality > 0
                let height: CGFloat = 4 + CGFloat(i) * 3
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(active ? color : color.opacity(0.2))
                    .frame(width: 3, height: height)
            }
        }
    }
}

// MARK: - Colors

/// Battery accent color — matches BatteryWidget logic.
private func batteryAccentColor(for bat: BatteryMetrics?) -> Color {
    guard let bat else { return .gray }
    if bat.isCharging { return .green }
    if bat.percentage < 10 { return .red }
    if bat.percentage < 20 { return .orange }
    if bat.percentage < 50 { return .yellow }
    return .green
}

/// Overall widget accent — worst-of battery / storage.
private func overallAccent(for entry: VitalsEntry) -> Color {
    let disk = entry.metrics.disk
    let bat = entry.metrics.battery

    let storageCritical = disk.usageRatio >= 0.8
    let storageWarn     = disk.usageRatio >= 0.6

    let batteryCritical: Bool = {
        guard let bat else { return false }
        return !bat.isCharging && bat.percentage < 10
    }()
    let batteryWarn: Bool = {
        guard let bat else { return false }
        return !bat.isCharging && bat.percentage < 20
    }()

    if batteryCritical || storageCritical { return .red }
    if batteryWarn || storageWarn { return .orange }
    return .green
}

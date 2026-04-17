import SwiftUI
import WidgetKit

struct NetworkInfoWidget: Widget {
    let kind = "NetworkInfoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VitalsTimelineProvider()) { entry in
            NetworkInfoWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetGradientBackground(accentColor: signalColor(for: entry.metrics.wifi))
                }
        }
        .configurationDisplayName("Network Info")
        .description("WiFi signal, SSID, and IP addresses.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NetworkInfoWidgetView: View {
    let entry: VitalsEntry
    @Environment(\.widgetFamily) var family

    private var wifi: WiFiMetrics { entry.metrics.wifi }
    private var isConnected: Bool {
        if let ssid = wifi.ssid, !ssid.isEmpty { return true }
        return wifi.rssi != nil || wifi.localIP != nil
    }
    private var displayName: String {
        if let ssid = wifi.ssid, !ssid.isEmpty { return ssid }
        return "Wi-Fi"
    }
    private var percent: Int { Int(wifi.signalQuality * 100) }
    private var color: Color { signalColor(for: wifi) }

    var body: some View {
        switch family {
        case .systemMedium: mediumBody
        default: smallBody
        }
    }

    private var smallBody: some View {
        if isConnected {
            return AnyView(smallConnected)
        } else {
            return AnyView(smallDisconnected)
        }
    }

    private var smallConnected: some View {
        VStack(spacing: 6) {
            WidgetHeader(icon: "wifi", title: "WIFI")

            ZStack {
                DonutRing(ratio: wifi.signalQuality, color: color)
                    .widgetAccentable()

                VStack(spacing: -2) {
                    BigPercent(percent: percent)
                    Text("signal")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .kerning(0.6)
                }
            }
            .frame(maxHeight: .infinity)

            Text(displayName)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var smallDisconnected: some View {
        VStack(spacing: 6) {
            WidgetHeader(icon: "wifi.slash", title: "WIFI")

            VStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(.secondary)
                Text("Not Connected")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var mediumBody: some View {
        if isConnected {
            return AnyView(mediumConnected)
        } else {
            return AnyView(mediumDisconnected)
        }
    }

    private var mediumConnected: some View {
        HStack(spacing: 18) {
            ZStack {
                DonutRing(ratio: wifi.signalQuality, color: color)
                    .widgetAccentable()
                BigPercent(percent: percent, numberSize: 28, symbolSize: 14)
            }
            .frame(width: 88, height: 88)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "wifi")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Network")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    NetworkStatRow(label: "Name", value: displayName, valueColor: color)
                    NetworkStatRow(label: "Local", value: wifi.localIP ?? "—", monospaced: true)
                    NetworkStatRow(label: "Public", value: wifi.publicIP ?? "—", monospaced: true)
                    if let rssi = wifi.rssi {
                        NetworkStatRow(label: "Signal", value: "\(rssi) dBm")
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var mediumDisconnected: some View {
        VStack(spacing: 6) {
            WidgetHeader(icon: "wifi.slash", title: "WIFI")

            VStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(.secondary)
                Text("Not Connected")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Network stat row (supports long SSID truncation)

private struct NetworkStatRow: View {
    let label: String
    let value: String
    var labelWidth: CGFloat = 44
    var valueColor: Color = .primary
    var monospaced: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

// MARK: - Signal color

func signalColor(for wifi: WiFiMetrics) -> Color {
    let hasSSID = (wifi.ssid?.isEmpty == false)
    let hasSignal = wifi.rssi != nil || wifi.localIP != nil
    guard hasSSID || hasSignal else { return .gray }
    let q = wifi.signalQuality
    if q >= 0.75 { return .green }
    if q >= 0.5 { return .yellow }
    if q >= 0.25 { return .orange }
    return .red
}

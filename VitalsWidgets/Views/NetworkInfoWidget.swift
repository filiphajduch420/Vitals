import SwiftUI
import WidgetKit

struct NetworkInfoWidget: Widget {
    let kind = "NetworkInfoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VitalsTimelineProvider()) { entry in
            NetworkInfoWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Network Info")
        .description("WiFi name, local IP, and public IP.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NetworkInfoWidgetView: View {
    let entry: VitalsEntry
    @Environment(\.widgetFamily) var family

    private var wifi: WiFiMetrics { entry.metrics.wifi }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: wifi.ssid != nil ? "wifi" : "wifi.slash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(wifi.ssid != nil ? .blue : .secondary)
                Text("Network")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
                if let ssid = wifi.ssid {
                    Text(ssid)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if wifi.ssid != nil {
                VStack(alignment: .leading, spacing: 6) {
                    if let ssid = wifi.ssid, ssid != "Connected" {
                        infoRow("wifi", "WiFi", ssid)
                    }
                    infoRow("network", "Local IP", wifi.localIP ?? "—")
                    infoRow("globe", "Public IP", wifi.publicIP ?? "—")

                    if family == .systemMedium {
                        HStack(spacing: 12) {
                            if let rssi = wifi.rssi {
                                compactStat("antenna.radiowaves.left.and.right", "Signal", "\(rssi) dBm")
                            }
                            if let ch = wifi.channel {
                                compactStat("number", "Channel", ch)
                            }
                            if let rate = wifi.txRate {
                                compactStat("arrow.up.arrow.down", "Speed", "\(rate) Mbps")
                            }
                            Spacer()
                        }
                    }
                }
            } else {
                Text("Not Connected")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func compactStat(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
        }
    }

    private func infoRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .lineLimit(1)
        }
    }
}

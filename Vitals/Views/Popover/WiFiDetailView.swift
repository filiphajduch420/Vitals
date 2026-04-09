import SwiftUI

struct WiFiDetailView: View {

    @Environment(AppState.self) private var appState

    private var wifi: WiFiMetrics { appState.metrics.wifi }

    var body: some View {
        GlassMorphicCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "wifi")
                        .scaledFont(13, weight: .semibold)
                        .foregroundStyle(wifi.ssid != nil ? .blue : .secondary)
                    Text("WiFi")
                        .scaledFont(12, weight: .semibold, design: .rounded)
                    Spacer()
                    if let ssid = wifi.ssid {
                        Text(ssid)
                            .scaledFont(11, weight: .medium)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not Connected")
                            .scaledFont(11)
                            .foregroundStyle(.secondary)
                    }
                }

                if wifi.ssid != nil {
                    HStack(spacing: 12) {
                        if let rssi = wifi.rssi {
                            iconStat("antenna.radiowaves.left.and.right", "\(rssi) dBm")
                        }
                        if let rate = wifi.txRate {
                            iconStat("arrow.up.arrow.down", "\(rate) Mbps")
                        }
                        if let ch = wifi.channel {
                            iconStat("number", "Ch \(ch)")
                        }
                    }
                    .scaledFont(10)
                    .foregroundStyle(.secondary)

                    if wifi.rssi != nil {
                        UsageBarView(value: wifi.signalQuality, color: signalColor, height: 4)
                    }

                    VStack(spacing: 3) {
                        if let localIP = wifi.localIP {
                            ipRow("network", "Local IP", localIP)
                        }
                        if let publicIP = wifi.publicIP {
                            ipRow("globe", "Public IP", publicIP)
                        }
                    }
                }
            }
        }
    }

    private var signalColor: Color {
        let q = wifi.signalQuality
        if q > 0.7 { return .green }
        if q > 0.4 { return .yellow }
        return .red
    }

    private func ipRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 12)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .scaledFont(10)
        .foregroundStyle(.secondary)
    }

    private func iconStat(_ icon: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
        }
    }
}

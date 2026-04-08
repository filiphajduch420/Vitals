import Foundation
import CoreWLAN
import SystemConfiguration

final class WiFiMonitor: @unchecked Sendable {

    private var cachedSSID: String?
    private var ssidRefreshCount = 0

    func read() -> WiFiMetrics {
        guard let iface = CWWiFiClient.shared().interface() else {
            return .empty
        }

        guard iface.powerOn() else {
            return .empty
        }

        let interfaceName = iface.interfaceName ?? "en0"
        let rssi = iface.rssiValue()
        let noise = iface.noiseMeasurement()
        let txRate = iface.transmitRate()

        var channelStr: String?
        if let ch = iface.wlanChannel() {
            channelStr = "\(ch.channelNumber)"
        }

        // SSID: try CWWiFi first, fallback to networksetup command
        var ssid = iface.ssid()
        if ssid == nil {
            ssidRefreshCount += 1
            if cachedSSID == nil || ssidRefreshCount >= 10 {
                ssidRefreshCount = 0
                cachedSSID = readSSIDViaShell(interfaceName)
            }
            ssid = cachedSSID
        } else {
            cachedSSID = ssid
            ssidRefreshCount = 0
        }

        // Determine connection: SSID available, RSSI non-zero, or interface has an IP
        let connected = ssid != nil || rssi != 0 || hasIPAddress(interfaceName)

        guard connected else {
            return .empty
        }

        return WiFiMetrics(
            ssid: ssid ?? "Connected",
            rssi: rssi != 0 ? rssi : nil,
            noise: noise != 0 ? noise : nil,
            txRate: txRate > 0 ? Int(txRate) : nil,
            channel: channelStr
        )
    }

    // MARK: - Shell fallback for SSID

    private func readSSIDViaShell(_ interfaceName: String) -> String? {
        let output = shell("/usr/sbin/networksetup", ["-getairportnetwork", interfaceName])

        // "You are not associated with an AirPort network."
        if output.contains("not associated") || output.isEmpty {
            return nil
        }
        // Format: "Current Wi-Fi Network: MyNetwork"
        let prefix = "Current Wi-Fi Network: "
        if let range = output.range(of: prefix) {
            let name = String(output[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        }
        return nil
    }

    // MARK: - IP address check (lightweight connectivity indicator)

    private func hasIPAddress(_ interfaceName: String) -> Bool {
        let output = shell("/usr/sbin/ipconfig", ["getifaddr", interfaceName])
        // Returns an IP like "192.168.1.42" if connected, empty otherwise
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Helpers

    private func shell(_ path: String, _ arguments: [String]) -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = arguments
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
        } catch {
            return ""
        }
        proc.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}

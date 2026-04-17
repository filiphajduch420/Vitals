import Foundation
import CoreWLAN
import SystemConfiguration

final class WiFiMonitor: @unchecked Sendable {

    private var cachedSSID: String?
    private var lastSSIDRefresh: Date = .distantPast
    private var cachedPublicIP: String?
    private var lastPublicIPRefresh: Date = .distantPast

    func read() async -> WiFiMetrics {
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

        // SSID — CoreWLAN needs Location Services on macOS 14+, so try fallbacks
        var ssid = iface.ssid()
        if ssid?.isEmpty != false {
            ssid = readSSIDViaSystemConfig(interfaceName)
        }
        if ssid?.isEmpty != false {
            if cachedSSID == nil || Date().timeIntervalSince(lastSSIDRefresh) >= 60 {
                lastSSIDRefresh = Date()
                cachedSSID = readSSIDViaShell(interfaceName)
            }
            ssid = cachedSSID
        } else {
            cachedSSID = ssid
            lastSSIDRefresh = Date()
        }

        let connected = ssid != nil || rssi != 0 || hasIPAddress(interfaceName)
        guard connected else { return .empty }

        // Local IP
        let localIP = getLocalIP(interfaceName)

        // Public IP — refresh every 5 minutes
        if cachedPublicIP == nil || Date().timeIntervalSince(lastPublicIPRefresh) >= 300 {
            lastPublicIPRefresh = Date()
            cachedPublicIP = await getPublicIP()
        }

        return WiFiMetrics(
            ssid: ssid ?? "Connected",
            rssi: rssi != 0 ? rssi : nil,
            noise: noise != 0 ? noise : nil,
            txRate: txRate > 0 ? Int(txRate) : nil,
            channel: channelStr,
            localIP: localIP,
            publicIP: cachedPublicIP
        )
    }

    // MARK: - IP addresses

    private func getLocalIP(_ interfaceName: String) -> String? {
        let output = shell("/usr/sbin/ipconfig", ["getifaddr", interfaceName])
        let ip = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return ip.isEmpty ? nil : ip
    }

    private func getPublicIP() async -> String? {
        guard let url = URL(string: "https://api.ipify.org") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }
            guard let ip = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !ip.isEmpty else { return nil }
            // Validate IP format: IPv4 or IPv6
            let ipv4Pattern = #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"#
            let isIPv4 = ip.range(of: ipv4Pattern, options: .regularExpression) != nil
            let isIPv6 = ip.contains(":")
            guard isIPv4 || isIPv6 else { return nil }
            return ip
        } catch {
            return nil
        }
    }

    // MARK: - Shell helpers

    private func readSSIDViaSystemConfig(_ interfaceName: String) -> String? {
        return autoreleasepool {
            guard let store = SCDynamicStoreCreate(nil, "Vitals" as CFString, nil, nil) else { return nil }
            let key = "State:/Network/Interface/\(interfaceName)/AirPort" as CFString
            guard let info = SCDynamicStoreCopyValue(store, key) as? [String: Any] else { return nil }
            return info["SSID_STR"] as? String
        }
    }

    private func readSSIDViaShell(_ interfaceName: String) -> String? {
        let output = shell("/usr/sbin/networksetup", ["-getairportnetwork", interfaceName])
        if output.contains("not associated") || output.isEmpty { return nil }
        let prefix = "Current Wi-Fi Network: "
        if let range = output.range(of: prefix) {
            let name = String(output[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        }
        return nil
    }

    private func hasIPAddress(_ interfaceName: String) -> Bool {
        getLocalIP(interfaceName) != nil
    }

    private func shell(_ path: String, _ arguments: [String]) -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = arguments
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do { try proc.run() } catch { return "" }
        proc.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}

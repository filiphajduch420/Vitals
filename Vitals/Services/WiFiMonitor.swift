import Foundation
import CoreWLAN
import SystemConfiguration

final class WiFiMonitor: @unchecked Sendable {

    private var cachedSSID: String?
    private var ssidRefreshCount = 0
    private var cachedPublicIP: String?
    private var publicIPRefreshCount = 0

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

        // SSID — CoreWLAN needs Location Services on macOS 14+, so try fallbacks
        var ssid = iface.ssid()
        if ssid == nil {
            ssid = readSSIDViaSystemConfig(interfaceName)
        }
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

        let connected = ssid != nil || rssi != 0 || hasIPAddress(interfaceName)
        guard connected else { return .empty }

        // Local IP
        let localIP = getLocalIP(interfaceName)

        // Public IP — refresh every 30 reads (~60s)
        publicIPRefreshCount += 1
        if cachedPublicIP == nil || publicIPRefreshCount >= 30 {
            publicIPRefreshCount = 0
            cachedPublicIP = getPublicIP()
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

    private func getPublicIP() -> String? {
        guard let url = URL(string: "https://api.ipify.org") else { return nil }
        let sem = DispatchSemaphore(value: 0)
        var result: String?
        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data, let ip = String(data: data, encoding: .utf8) {
                result = ip.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            sem.signal()
        }
        task.resume()
        _ = sem.wait(timeout: .now() + 3)
        return result
    }

    // MARK: - Shell helpers

    private func readSSIDViaSystemConfig(_ interfaceName: String) -> String? {
        guard let store = SCDynamicStoreCreate(nil, "Vitals" as CFString, nil, nil) else { return nil }
        let key = "State:/Network/Interface/\(interfaceName)/AirPort" as CFString
        guard let info = SCDynamicStoreCopyValue(store, key) as? [String: Any] else { return nil }
        return info["SSID_STR"] as? String
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

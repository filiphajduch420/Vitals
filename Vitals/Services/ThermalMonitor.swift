import Foundation
import IOKit

final class ThermalMonitor: @unchecked Sendable {

    private let smcConnection: io_connect_t

    init() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMCKeysEndpoint"))
        if service != 0 {
            var conn: io_connect_t = 0
            if IOServiceOpen(service, mach_task_self_, 0, &conn) == KERN_SUCCESS {
                smcConnection = conn
                // SMC connected
            } else {
                smcConnection = 0
            }
            IOObjectRelease(service)
        } else {
            smcConnection = 0
        }
    }

    deinit {
        if smcConnection != 0 { IOServiceClose(smcConnection) }
    }

    func read() -> ThermalMetrics {
        let state = ProcessInfo.processInfo.thermalState
        let stateLabel: String
        let level: Double

        switch state {
        case .nominal:  stateLabel = "Normal"; level = 0.1
        case .fair:     stateLabel = "Warm"; level = 0.4
        case .serious:  stateLabel = "Hot"; level = 0.75
        case .critical: stateLabel = "Critical"; level = 1.0
        @unknown default: stateLabel = "Unknown"; level = 0.0
        }

        var cpuTemp: Double?
        var gpuTemp: Double?
        var fanRPM: Int?
        var ssdTemp: Double?
        var systemPower: Double?

        if smcConnection != 0 {
            // CPU die temps
            var temps: [Double] = []
            for key in ["Tp01", "Tp05", "Tp09"] {
                if let v = smcRead(smcConnection, key: key), v > 0, v < 120 {
                    temps.append(v)
                }
            }
            if !temps.isEmpty {
                cpuTemp = temps.reduce(0, +) / Double(temps.count)
            }

            // GPU die temp
            if let v = smcRead(smcConnection, key: "Tg0D"), v > 0, v < 120 {
                gpuTemp = v
            }

            // Fan RPM
            if let v = smcRead(smcConnection, key: "F0Ac") {
                fanRPM = max(0, Int(v))
            }

            // SSD temp
            if let v = smcRead(smcConnection, key: "TH0x"), v > 0, v < 120 {
                ssdTemp = v
            }

            // System power (PSTR = total system power in watts)
            if let v = smcRead(smcConnection, key: "PSTR"), v > 0 {
                systemPower = v
            }
        }

        return ThermalMetrics(
            stateLabel: stateLabel,
            level: level,
            cpuTemperature: cpuTemp,
            gpuTemperature: gpuTemp,
            fanRPM: fanRPM,
            batteryTemperature: readBatteryTemp(),
            ssdTemperature: ssdTemp,
            systemPower: systemPower
        )
    }

    // MARK: - Standalone SMC read (no member structs)

    private func smcRead(_ conn: io_connect_t, key: String) -> Double? {
        // Build key as UInt32 (big-endian encoding of 4 ASCII chars)
        var k: UInt32 = 0
        for c in key.utf8 { k = (k << 8) | UInt32(c) }

        // Use the actual Swift struct — same one that works from CLI
        var input = SMCParam()
        var output = SMCParam()
        input.key = k
        input.data8 = 9 // getKeyInfo

        var outSz = MemoryLayout<SMCParam>.size

        let r1 = withUnsafeMutablePointer(to: &input) { inPtr in
            withUnsafeMutablePointer(to: &output) { outPtr in
                IOConnectCallStructMethod(conn, 2,
                    inPtr, MemoryLayout<SMCParam>.size,
                    outPtr, &outSz)
            }
        }

        guard r1 == KERN_SUCCESS && outSz >= MemoryLayout<SMCParam>.size else {
            return nil
        }
        guard output.keyInfo.dataSize > 0 else { return nil }

        // Read value
        var input2 = SMCParam()
        var output2 = SMCParam()
        input2.key = k
        input2.keyInfo.dataSize = output.keyInfo.dataSize
        input2.data8 = 5 // readKey

        outSz = MemoryLayout<SMCParam>.size

        let r2 = withUnsafeMutablePointer(to: &input2) { inPtr in
            withUnsafeMutablePointer(to: &output2) { outPtr in
                IOConnectCallStructMethod(conn, 2,
                    inPtr, MemoryLayout<SMCParam>.size,
                    outPtr, &outSz)
            }
        }

        guard r2 == KERN_SUCCESS && outSz >= MemoryLayout<SMCParam>.size else { return nil }

        if output.keyInfo.dataSize >= 4 {
            let b = withUnsafeBytes(of: output2.bytes) { Array($0.prefix(4)) }
            var f: Float = 0
            withUnsafeMutableBytes(of: &f) { buf in
                buf[0] = b[0]; buf[1] = b[1]; buf[2] = b[2]; buf[3] = b[3]
            }
            return Double(f)
        }
        return nil
    }

    private struct SMCParam {
        struct KeyInfo {
            var dataSize: IOByteCount32 = 0
            var dataType: UInt32 = 0
            var dataAttributes: UInt8 = 0
        }
        var key: UInt32 = 0
        var vers: (UInt8,UInt8,UInt8,UInt8,UInt8,UInt8) = (0,0,0,0,0,0)
        var pLimitData: (UInt16,UInt16,UInt16,UInt16,UInt16,UInt16,UInt16,UInt16) = (0,0,0,0,0,0,0,0)
        var keyInfo: KeyInfo = KeyInfo()
        var padding: UInt16 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    }

    // MARK: - Battery temp

    private func readBatteryTemp() -> Double? {
        let svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard svc != 0 else { return nil }
        defer { IOObjectRelease(svc) }
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(svc, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any],
              let raw = dict["Temperature"] as? Int else { return nil }
        return Double(raw) / 100.0
    }

}

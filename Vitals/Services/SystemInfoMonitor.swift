import Foundation

final class SystemInfoMonitor: @unchecked Sendable {

    private var cachedModelName: String?

    func read() -> SystemInfoMetrics {
        let hostname = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        let username = NSFullUserName()
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let osVersion = "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        let uptime = ProcessInfo.processInfo.systemUptime

        if cachedModelName == nil {
            cachedModelName = readModelName()
        }

        return SystemInfoMetrics(
            hostname: hostname,
            username: username,
            osVersion: osVersion,
            modelName: cachedModelName ?? "Mac",
            uptime: uptime
        )
    }

    private func readModelName() -> String? {
        var size: Int = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var model = [UInt8](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(decoding: model.prefix(while: { $0 != 0 }), as: UTF8.self)
    }
}

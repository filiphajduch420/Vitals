import Foundation
import WidgetKit
import os

enum DataSharingManager {

    private static let groupID: String = {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String ?? ""
    }()
    private static let fileName = "metrics.json"

    private static var sharedFileURL: URL? {
        if let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent(fileName) {
            return url
        }
        // Fallback: construct Group Container path manually
        guard !groupID.isEmpty else { return nil }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let url = home
            .appendingPathComponent("Library/Group Containers")
            .appendingPathComponent(groupID)
            .appendingPathComponent(fileName)
        return url
    }

    /// Serializes metrics writes off the main thread. The single actor instance
    /// guarantees there are never two overlapping writes, and running the encode
    /// plus disk I/O here keeps them off the @MainActor UI thread.
    private actor FileWriter {
        static let shared = FileWriter()
        private var directoryEnsured = false

        func write(_ metrics: SystemMetrics, to url: URL) {
            do {
                // Ensure directory exists — only needs to happen once.
                if !directoryEnsured {
                    let dir = url.deletingLastPathComponent()
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    directoryEnsured = true
                }
                let data = try JSONEncoder().encode(metrics)
                // Create the file up-front with 0600 so it is never world-readable,
                // not even for the brief window a write-then-chmod would leave open.
                // Atomic writes preserve the mode of an existing destination file.
                if !FileManager.default.fileExists(atPath: url.path) {
                    FileManager.default.createFile(
                        atPath: url.path,
                        contents: nil,
                        attributes: [.posixPermissions: 0o600]
                    )
                }
                try data.write(to: url, options: .atomic)
            } catch {
                VitalsLog.sharing.error("writeMetrics failed: \(error.localizedDescription)")
            }
        }
    }

    static func writeMetrics(_ metrics: SystemMetrics) {
        guard let url = sharedFileURL else {
            VitalsLog.sharing.error("writeMetrics: no container URL")
            return
        }
        Task.detached(priority: .utility) {
            await FileWriter.shared.write(metrics, to: url)
        }
    }

    static func readMetrics() -> SystemMetrics? {
        guard let url = sharedFileURL else {
            VitalsLog.sharing.error("readMetrics: no container URL")
            return nil
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            VitalsLog.sharing.warning("readMetrics: file does not exist at \(url.path)")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            guard !data.isEmpty else {
                VitalsLog.sharing.warning("readMetrics: file is empty")
                return nil
            }
            VitalsLog.sharing.debug("readMetrics: read \(data.count) bytes")
            let metrics = try JSONDecoder().decode(SystemMetrics.self, from: data)
            VitalsLog.sharing.debug("readMetrics: decoded OK, cpu=\(metrics.cpu.totalUsage)")
            return metrics
        } catch {
            VitalsLog.sharing.error("readMetrics failed: \(error.localizedDescription)")
            return nil
        }
    }

    @MainActor
    static func refreshWidgetsIfNeeded() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

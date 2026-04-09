import Foundation
import WidgetKit
import os

private let logger = Logger(subsystem: "com.filiphajduch.vitals", category: "DataSharing")

enum DataSharingManager {

    private static let groupID: String = {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String ?? ""
    }()
    private static let fileName = "metrics.json"

    private static var sharedFileURL: URL? {
        let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent(fileName)
        return url
    }

    static func writeMetrics(_ metrics: SystemMetrics) {
        guard let url = sharedFileURL else {
            logger.error("writeMetrics: no container URL")
            return
        }
        do {
            // Ensure directory exists
            let dir = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(metrics)
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("writeMetrics failed: \(error.localizedDescription)")
        }
    }

    static func readMetrics() -> SystemMetrics? {
        guard let url = sharedFileURL else {
            logger.error("readMetrics: no container URL")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            logger.info("readMetrics: read \(data.count) bytes")
            let metrics = try JSONDecoder().decode(SystemMetrics.self, from: data)
            logger.info("readMetrics: decoded OK, cpu=\(metrics.cpu.totalUsage)")
            return metrics
        } catch {
            logger.error("readMetrics failed: \(error.localizedDescription)")
            return nil
        }
    }

    @MainActor
    static func refreshWidgetsIfNeeded() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

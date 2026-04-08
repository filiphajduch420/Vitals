import Foundation
import WidgetKit

enum DataSharingManager {

    private static var defaults: UserDefaults { .standard }

    static func writeMetrics(_ metrics: SystemMetrics) {
        guard let data = try? JSONEncoder().encode(metrics) else { return }
        defaults.set(data, forKey: "latestMetrics")
    }

    static func readMetrics() -> SystemMetrics? {
        guard let data = defaults.data(forKey: "latestMetrics") else { return nil }
        return try? JSONDecoder().decode(SystemMetrics.self, from: data)
    }

    @MainActor
    static func refreshWidgetsIfNeeded() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

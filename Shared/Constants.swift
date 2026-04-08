import Foundation

enum AppConstants {
    static let appGroupID = "group.com.filiphajduch.vitals"
    static let appName = "Vitals"
}

extension UserDefaults {
    /// Shared UserDefaults for app settings.
    @MainActor
    static let appGroup: UserDefaults = .standard
}

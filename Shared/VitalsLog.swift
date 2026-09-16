import Foundation
import os

/// Central logging facade shared by the main app and the widget extension
/// (both targets compile `Shared/`). One `os.Logger` per area so output can be
/// filtered by category, for example:
///
///     log show --predicate 'subsystem == "com.filiphajduch.vitals"' --info --debug --last 30m
///
/// Privacy: interpolated dynamic values default to `.private` (redacted as
/// `<private>` in log output). Only mark non-sensitive scalars `.public`; never
/// log IP addresses or Wi-Fi SSIDs at `.info` or above.
enum VitalsLog {

    /// Unified subsystem for every `Logger` in the app and widget extension.
    static let subsystem = "com.filiphajduch.vitals"

    // MARK: - App-wide

    /// App lifecycle (start/stop monitoring, general events).
    static let app = Logger(subsystem: subsystem, category: "app")
    /// Power state: AC ↔ battery switches, sleep/wake pausing.
    static let power = Logger(subsystem: subsystem, category: "power")
    /// App Group container read/write of `metrics.json`.
    static let sharing = Logger(subsystem: subsystem, category: "sharing")
    /// Widget timeline provider (data freshness, decode failures).
    static let widgets = Logger(subsystem: subsystem, category: "widgets")

    // MARK: - Per-monitor

    static let cpu = Logger(subsystem: subsystem, category: "cpu")
    static let gpu = Logger(subsystem: subsystem, category: "gpu")
    static let memory = Logger(subsystem: subsystem, category: "memory")
    static let battery = Logger(subsystem: subsystem, category: "battery")
    static let thermal = Logger(subsystem: subsystem, category: "thermal")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let wifi = Logger(subsystem: subsystem, category: "wifi")
    static let disk = Logger(subsystem: subsystem, category: "disk")
    static let systemInfo = Logger(subsystem: subsystem, category: "systemInfo")
}

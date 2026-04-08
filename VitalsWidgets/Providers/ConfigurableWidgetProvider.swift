import WidgetKit
@preconcurrency import AppIntents

// MARK: - App Intent for metric selection

enum WidgetMetricChoice: String, CaseIterable, AppEnum {
    case cpu = "CPU"
    case memory = "Memory"
    case network = "Network"
    case battery = "Battery"
    case disk = "Disk"

    nonisolated static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Metric")
    }

    nonisolated static var caseDisplayRepresentations: [WidgetMetricChoice: DisplayRepresentation] {
        [
            .cpu: DisplayRepresentation(title: "CPU", image: .init(systemName: "cpu.fill")),
            .memory: DisplayRepresentation(title: "Memory", image: .init(systemName: "memorychip.fill")),
            .network: DisplayRepresentation(title: "Network", image: .init(systemName: "network")),
            .battery: DisplayRepresentation(title: "Battery", image: .init(systemName: "battery.75percent")),
            .disk: DisplayRepresentation(title: "Disk", image: .init(systemName: "internaldrive.fill")),
        ]
    }
}

// MARK: - Single Metric Intent

struct SingleMetricIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Select Metric"
    static let description: IntentDescription = "Choose which metric to display."

    @Parameter(title: "Metric", default: .cpu)
    var metric: WidgetMetricChoice
}

// MARK: - Dual Metric Intent

struct DualMetricIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Select Metrics"
    static let description: IntentDescription = "Choose two metrics to display."

    @Parameter(title: "First Metric", default: .cpu)
    var metric1: WidgetMetricChoice

    @Parameter(title: "Second Metric", default: .memory)
    var metric2: WidgetMetricChoice
}

// MARK: - Quad Metric Intent

struct QuadMetricIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Select Metrics"
    static let description: IntentDescription = "Choose four metrics to display."

    @Parameter(title: "Metric 1", default: .cpu)
    var metric1: WidgetMetricChoice

    @Parameter(title: "Metric 2", default: .memory)
    var metric2: WidgetMetricChoice

    @Parameter(title: "Metric 3", default: .network)
    var metric3: WidgetMetricChoice

    @Parameter(title: "Metric 4", default: .disk)
    var metric4: WidgetMetricChoice
}

// MARK: - Timeline Entries

struct SingleMetricEntry: TimelineEntry {
    let date: Date
    let metrics: SystemMetrics
    let choice: WidgetMetricChoice
}

struct DualMetricEntry: TimelineEntry {
    let date: Date
    let metrics: SystemMetrics
    let choice1: WidgetMetricChoice
    let choice2: WidgetMetricChoice
}

struct QuadMetricEntry: TimelineEntry {
    let date: Date
    let metrics: SystemMetrics
    let choice1: WidgetMetricChoice
    let choice2: WidgetMetricChoice
    let choice3: WidgetMetricChoice
    let choice4: WidgetMetricChoice
}

// MARK: - Providers

struct SingleMetricProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SingleMetricEntry {
        SingleMetricEntry(date: .now, metrics: .empty, choice: .cpu)
    }

    func snapshot(for configuration: SingleMetricIntent, in context: Context) async -> SingleMetricEntry {
        SingleMetricEntry(
            date: .now,
            metrics: DataSharingManager.readMetrics() ?? .empty,
            choice: configuration.metric
        )
    }

    func timeline(for configuration: SingleMetricIntent, in context: Context) async -> Timeline<SingleMetricEntry> {
        let entry = SingleMetricEntry(
            date: .now,
            metrics: DataSharingManager.readMetrics() ?? .empty,
            choice: configuration.metric
        )
        let next = Calendar.current.date(byAdding: .minute, value: 1, to: .now)!
        return Timeline(entries: [entry], policy: .after(next))
    }
}

struct DualMetricProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DualMetricEntry {
        DualMetricEntry(date: .now, metrics: .empty, choice1: .cpu, choice2: .memory)
    }

    func snapshot(for configuration: DualMetricIntent, in context: Context) async -> DualMetricEntry {
        DualMetricEntry(
            date: .now,
            metrics: DataSharingManager.readMetrics() ?? .empty,
            choice1: configuration.metric1,
            choice2: configuration.metric2
        )
    }

    func timeline(for configuration: DualMetricIntent, in context: Context) async -> Timeline<DualMetricEntry> {
        let entry = DualMetricEntry(
            date: .now,
            metrics: DataSharingManager.readMetrics() ?? .empty,
            choice1: configuration.metric1,
            choice2: configuration.metric2
        )
        let next = Calendar.current.date(byAdding: .minute, value: 1, to: .now)!
        return Timeline(entries: [entry], policy: .after(next))
    }
}

struct QuadMetricProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> QuadMetricEntry {
        QuadMetricEntry(date: .now, metrics: .empty, choice1: .cpu, choice2: .memory, choice3: .network, choice4: .disk)
    }

    func snapshot(for configuration: QuadMetricIntent, in context: Context) async -> QuadMetricEntry {
        let m = DataSharingManager.readMetrics() ?? .empty
        return QuadMetricEntry(date: .now, metrics: m, choice1: configuration.metric1, choice2: configuration.metric2, choice3: configuration.metric3, choice4: configuration.metric4)
    }

    func timeline(for configuration: QuadMetricIntent, in context: Context) async -> Timeline<QuadMetricEntry> {
        let m = DataSharingManager.readMetrics() ?? .empty
        let entry = QuadMetricEntry(date: .now, metrics: m, choice1: configuration.metric1, choice2: configuration.metric2, choice3: configuration.metric3, choice4: configuration.metric4)
        let next = Calendar.current.date(byAdding: .minute, value: 1, to: .now)!
        return Timeline(entries: [entry], policy: .after(next))
    }
}

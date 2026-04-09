import SwiftUI
import WidgetKit

struct SystemHealthWidget: Widget {
    let kind = "SystemHealthWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VitalsTimelineProvider()) { entry in
            SystemHealthWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("System Health")
        .description("At-a-glance system status indicator.")
        .supportedFamilies([.systemSmall])
    }
}

struct SystemHealthWidgetView: View {
    let entry: VitalsEntry

    private var m: SystemMetrics { entry.metrics }

    private var status: (color: Color, label: String, icon: String) {
        // Critical
        if m.cpu.totalUsage > 0.9 { return (.red, "CPU Critical", "exclamationmark.triangle.fill") }
        if m.memory.usageRatio > 0.95 { return (.red, "Memory Critical", "exclamationmark.triangle.fill") }
        if m.disk.usageRatio > 0.95 { return (.red, "Disk Full", "exclamationmark.triangle.fill") }
        if let temp = m.thermal.cpuTemperature, temp > 95 { return (.red, "Overheating", "exclamationmark.triangle.fill") }
        if let bat = m.battery, bat.percentage < 5, !bat.isPluggedIn { return (.red, "Battery Critical", "exclamationmark.triangle.fill") }

        // Warning
        if m.cpu.totalUsage > 0.7 { return (.yellow, "CPU High", "exclamationmark.circle.fill") }
        if m.memory.usageRatio > 0.85 { return (.yellow, "Memory High", "exclamationmark.circle.fill") }
        if m.disk.usageRatio > 0.85 { return (.yellow, "Disk Low", "exclamationmark.circle.fill") }
        if let temp = m.thermal.cpuTemperature, temp > 80 { return (.yellow, "Warm", "exclamationmark.circle.fill") }
        if let bat = m.battery, bat.percentage < 15, !bat.isPluggedIn { return (.yellow, "Battery Low", "exclamationmark.circle.fill") }

        // All good
        return (.green, "All Good", "checkmark.circle.fill")
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: status.icon)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(status.color)

            Text(status.label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))

            Text("CPU \(Int(m.cpu.totalUsage * 100))% \u{2022} RAM \(Int(m.memory.usageRatio * 100))%")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

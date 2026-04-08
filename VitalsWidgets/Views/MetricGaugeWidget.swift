import SwiftUI

/// Reusable gauge view for displaying a single metric in a widget.
struct MetricGaugeWidget: View {
    let choice: WidgetMetricChoice
    let metrics: SystemMetrics
    var size: CGFloat = 56
    var showLabel: Bool = true

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: size * 0.25))
                .foregroundStyle(color)

            GaugeView(
                value: value,
                lineWidth: size * 0.09,
                size: size,
                color: color
            )

            if showLabel {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var value: Double {
        switch choice {
        case .cpu:     return metrics.cpu.totalUsage
        case .memory:  return metrics.memory.usageRatio
        case .network: return min(Double(metrics.network.downloadSpeed) / (100 * 1024 * 1024), 1.0)
        case .battery: return Double(metrics.battery?.percentage ?? 0) / 100.0
        case .disk:    return metrics.disk.usageRatio
        }
    }

    private var icon: String {
        switch choice {
        case .cpu:     return "cpu.fill"
        case .memory:  return "memorychip.fill"
        case .network: return "network"
        case .battery:
            if metrics.battery?.isCharging == true { return "battery.100percent.bolt" }
            return "battery.75percent"
        case .disk:    return "internaldrive.fill"
        }
    }

    private var label: String {
        switch choice {
        case .cpu:     return "CPU"
        case .memory:  return "Memory"
        case .network: return "Network"
        case .battery: return "Battery"
        case .disk:    return "Disk"
        }
    }

    private var color: Color {
        switch choice {
        case .battery:
            if metrics.battery?.isCharging == true { return .green }
            let pct = metrics.battery?.percentage ?? 0
            return pct < 10 ? .red : pct < 20 ? .orange : .green
        default:
            return usageColor(value)
        }
    }
}

import SwiftUI

/// Dedicated popover card listing the top CPU / RAM consumers, switchable via a
/// segmented picker. Broken out of the CPU and Memory details so it can be
/// reordered and toggled like any other section.
struct TopProcessesDetailView: View {

    @Environment(AppState.self) private var appState

    /// Which metric the list is ranked by. Both lists are kept fresh by a single
    /// scan (see `AppState.refreshTopProcesses()`), so flipping the picker never
    /// triggers extra work.
    private enum Metric: String, CaseIterable, Identifiable {
        case cpu, memory
        var id: String { rawValue }
        var label: String {
            switch self {
            case .cpu:    return "CPU"
            case .memory: return String(localized: "Memory")
            }
        }
    }

    @State private var metric: Metric = .cpu

    private var processes: [ProcessUsage] {
        metric == .cpu ? appState.topProcessesByCPU : appState.topProcessesByMemory
    }

    var body: some View {
        GlassMorphicCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .scaledFont(13, weight: .semibold)
                        .foregroundStyle(.orange)
                    Text("Top Processes")
                        .scaledFont(12, weight: .semibold, design: .rounded)
                    Spacer()
                }

                Picker("Metric", selection: $metric) {
                    ForEach(Metric.allCases) { metric in
                        Text(metric.label).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                VStack(spacing: 4) {
                    if processes.isEmpty {
                        Text("Gathering…")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(processes) { proc in
                            processRow(proc)
                        }
                    }
                }
                .scaledFont(10)
                .adaptiveSecondary()
            }
        }
        // The process scan is expensive, so it runs only while the popover is
        // actually on screen. The popover is a reused NSPanel that does not
        // reliably fire `onDisappear` on hide, so we cannot rely on `.task`
        // cancellation alone — each scan is gated on `isPopoverVisible`, which
        // StatusBarController toggles in show/hidePanel(). When hidden the loop
        // idles without scanning and resumes automatically on the next open.
        .task {
            while !Task.isCancelled {
                if appState.isPopoverVisible {
                    await appState.refreshTopProcesses()
                }
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private func processRow(_ proc: ProcessUsage) -> some View {
        HStack(spacing: 6) {
            Text(proc.name)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 6)
            Text(value(for: proc))
                .fontWeight(.medium)
                .monospacedDigit()
        }
    }

    private func value(for proc: ProcessUsage) -> String {
        switch metric {
        case .cpu:    return Formatters.formatCPUPercent(proc.cpuPercent)
        case .memory: return Formatters.formatBytes(proc.memoryBytes)
        }
    }
}

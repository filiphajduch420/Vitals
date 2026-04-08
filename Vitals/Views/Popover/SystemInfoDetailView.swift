import SwiftUI

struct SystemInfoDetailView: View {

    @Environment(AppState.self) private var appState

    private var info: SystemInfoMetrics { appState.metrics.systemInfo }

    var body: some View {
        GlassMorphicCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "desktopcomputer")
                        .scaledFont(13, weight: .semibold)
                        .foregroundStyle(.blue)
                    Text("System")
                        .scaledFont(12, weight: .semibold, design: .rounded)
                    Spacer()
                    Text(info.modelName)
                        .scaledFont(11, weight: .medium)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    infoRow("person.fill", "User", info.username)
                    infoRow("laptopcomputer", "Name", info.hostname)
                    infoRow("gear", "macOS", info.osVersion)
                    infoRow("clock.fill", "Uptime", info.formattedUptime)
                }
            }
        }
    }

    private func infoRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 12, alignment: .center)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .scaledFont(10)
        .foregroundStyle(.secondary)
    }
}

import SwiftUI

struct PopoverView: View {

    @Environment(AppState.self) private var appState

    /// Computed in body scope so @Observable tracks all section visibility properties
    private var visibleSections: [PopoverSection] {
        appState.sectionOrder.filter { appState.isSectionVisible($0) }
    }

    var body: some View {
        let sections = visibleSections
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 8) {
                // Header in glass
                GlassMorphicCard {
                    HStack {
                        Text("Vitals")
                            .scaledFont(16, weight: .bold, design: .rounded)
                        Spacer()
                        Button {
                            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
                        } label: {
                            Image(systemName: "gauge.with.dots.needle.33percent")
                                .scaledFont(13, weight: .medium)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)

                        SettingsLink {
                            Image(systemName: "gearshape.fill")
                                .scaledFont(13, weight: .medium)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                    }
                }

                ForEach(sections) { section in
                    sectionView(for: section)
                }
            }
            .padding(10)
        }
        .environment(\.glassOpacity, appState.glassOpacity)
        .environment(\.glassVariantEnv, appState.glassVariant)
        .environment(\.textScale, appState.textScale)
        .frame(width: 280)
    }

    @ViewBuilder
    private func sectionView(for section: PopoverSection) -> some View {
        switch section {
        case .system:  SystemInfoDetailView()
        case .cpu:     CPUDetailView()
        case .gpu:     GPUDetailView()
        case .memory:  MemoryDetailView()
        case .network: NetworkDetailView()
        case .battery: BatteryDetailView()
        case .disk:    DiskDetailView()
        case .wifi:    WiFiDetailView()
        }
    }
}

import SwiftUI

struct AppearanceSettingsView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Form {
            // MARK: - Glass Style
            Section {
                Picker("Glass Style", selection: Binding(
                    get: { appState.glassVariant },
                    set: { appState.glassVariant = $0 }
                )) {
                    ForEach(GlassVariant.allCases) { variant in
                        Text(variant.label).tag(variant)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent("Opacity") {
                    HStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { appState.glassOpacity },
                                set: { appState.glassOpacity = $0 }
                            ),
                            in: 0...0.8,
                            step: 0.05
                        )
                        Text("\(Int(appState.glassOpacity * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }

                // Live preview
                LiquidGlassBackground(
                    variant: appState.glassVariant,
                    cornerRadius: 14
                ) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                        Text("Glass Preview")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Spacer()
                        Text("Style \(appState.glassVariant.label)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill((colorScheme == .dark ? Color.black : Color.white).opacity(appState.glassOpacity))
                    )
                }
                .frame(height: 46)
            } header: {
                Label("Glass Effect", systemImage: "drop.halffull")
            }

            // MARK: - Text Size
            Section {
                LabeledContent("Scale") {
                    HStack(spacing: 8) {
                        Image(systemName: "textformat.size.smaller")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Slider(
                            value: Binding(
                                get: { appState.textScale },
                                set: { appState.textScale = $0 }
                            ),
                            in: 0.8...1.3,
                            step: 0.05
                        )
                        Image(systemName: "textformat.size.larger")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text("\(Int(appState.textScale * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            } header: {
                Label("Text Size", systemImage: "textformat.size")
            }

            // MARK: - Section Order
            Section {
                ForEach(Array(appState.sectionOrder.enumerated()), id: \.element) { index, section in
                    HStack(spacing: 10) {
                        Toggle(isOn: sectionBinding(for: section)) {
                            Text(section.label)
                        }

                        Spacer()

                        HStack(spacing: 2) {
                            Button {
                                moveSection(at: index, direction: -1)
                            } label: {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 10, weight: .semibold))
                                    .frame(width: 22, height: 22)
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == 0)

                            Button {
                                moveSection(at: index, direction: 1)
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .frame(width: 22, height: 22)
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == appState.sectionOrder.count - 1)
                        }
                    }
                }
            } header: {
                Label("Section Order", systemImage: "list.bullet")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func moveSection(at index: Int, direction: Int) {
        let newIndex = index + direction
        guard newIndex >= 0, newIndex < appState.sectionOrder.count else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            appState.sectionOrder.swapAt(index, newIndex)
        }
    }

    private func sectionBinding(for section: PopoverSection) -> Binding<Bool> {
        switch section {
        case .system:  return binding(\.sectionSystem)
        case .cpu:     return binding(\.sectionCPU)
        case .memory:  return binding(\.sectionMemory)
        case .network: return binding(\.sectionNetwork)
        case .battery: return binding(\.sectionBattery)
        case .disk:    return binding(\.sectionDisk)
        case .wifi:    return binding(\.sectionWiFi)
        }
    }

    private func binding(_ keyPath: ReferenceWritableKeyPath<AppState, Bool>) -> Binding<Bool> {
        Binding(
            get: { appState[keyPath: keyPath] },
            set: { appState[keyPath: keyPath] = $0 }
        )
    }
}

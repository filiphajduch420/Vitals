import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {

    @Environment(AppState.self) private var appState
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = !newValue
                        }
                    }
            }

            Section("Update Interval") {
                Picker("Refresh every", selection: Binding(
                    get: { appState.updateInterval },
                    set: { appState.updateInterval = $0 }
                )) {
                    Text("1s").tag(1.0)
                    Text("2s").tag(2.0)
                    Text("5s").tag(5.0)
                    Text("10s").tag(10.0)
                }
                .pickerStyle(.segmented)
            }

            Section {
                ForEach(Array(appState.menuBarOrder.enumerated()), id: \.element) { index, item in
                    HStack(spacing: 10) {
                        Toggle(isOn: menuBarBinding(for: item)) {
                            Text(item.label)
                        }

                        Spacer()

                        HStack(spacing: 2) {
                            Button {
                                moveMenuBarItem(at: index, direction: -1)
                            } label: {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 10, weight: .semibold))
                                    .frame(width: 22, height: 22)
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == 0)

                            Button {
                                moveMenuBarItem(at: index, direction: 1)
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .frame(width: 22, height: 22)
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == appState.menuBarOrder.count - 1)
                        }
                    }
                }

                Button {
                    resetMenuBarDefaults()
                } label: {
                    Label("Reset to Default", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
            } header: {
                Label("Menu Bar Items", systemImage: "menubar.rectangle")
            }

            Section("About") {
                LabeledContent("App", value: "Vitals")
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                LabeledContent("Author", value: "Filip Hajduch")
                HStack {
                    Text("GitHub")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Link("filiphajduch420/Vitals", destination: URL(string: "https://github.com/filiphajduch420/Vitals")!)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func moveMenuBarItem(at index: Int, direction: Int) {
        let newIndex = index + direction
        guard newIndex >= 0, newIndex < appState.menuBarOrder.count else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            appState.menuBarOrder.swapAt(index, newIndex)
        }
    }

    private func resetMenuBarDefaults() {
        withAnimation {
            appState.menuBarOrder = MenuBarItem.allCases
            appState.barCPUUsage = true
            appState.barCPUTemp = false
            appState.barFanRPM = false
            appState.barGPU = true
            appState.barPower = false
            appState.barMemory = true
            appState.barNetworkDown = false
            appState.barNetworkUp = false
            appState.barBattery = false
            appState.barBatteryTime = false
            appState.barDisk = false
            appState.barIP = false
        }
    }

    private func menuBarBinding(for item: MenuBarItem) -> Binding<Bool> {
        let kp = appState.menuBarBinding(for: item)
        return Binding(
            get: { appState[keyPath: kp] },
            set: { appState[keyPath: kp] = $0 }
        )
    }
}

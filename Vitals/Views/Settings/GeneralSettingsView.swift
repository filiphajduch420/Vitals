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

            Section("Menu Bar Items") {
                Toggle("CPU Usage", isOn: binding(\.barCPUUsage))
                Toggle("CPU Temperature", isOn: binding(\.barCPUTemp))
                Toggle("Fan Speed", isOn: binding(\.barFanRPM))
                Toggle("System Power", isOn: binding(\.barPower))
                Toggle("Memory", isOn: binding(\.barMemory))
                Toggle("Network Download", isOn: binding(\.barNetworkDown))
                Toggle("Network Upload", isOn: binding(\.barNetworkUp))
                Toggle("Battery", isOn: binding(\.barBattery))
                Toggle("Disk Usage", isOn: binding(\.barDisk))
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                LabeledContent("App", value: "Vitals")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func binding(_ keyPath: ReferenceWritableKeyPath<AppState, Bool>) -> Binding<Bool> {
        Binding(
            get: { appState[keyPath: keyPath] },
            set: { appState[keyPath: keyPath] = $0 }
        )
    }
}

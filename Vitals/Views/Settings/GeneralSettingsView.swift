import SwiftUI
import ServiceManagement
import AppKit

struct GeneralSettingsView: View {

    @Environment(AppState.self) private var appState
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var showBatteryInfo = false
    @State private var copiedLogCommand = false
    @State private var updateState: UpdateState = .idle
    @State private var language: AppLanguage = .current

    /// Inline status shown next to the "Check for Updates" button.
    private enum UpdateState: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(version: String, url: URL)
        case failed
    }

    /// UI language override applied through the per-app `AppleLanguages` default.
    /// `.system` clears the override so the app follows the system language.
    private enum AppLanguage: String, CaseIterable, Identifiable {
        case system, english, czech

        var id: String { rawValue }

        /// Language code written to the per-app `AppleLanguages` array, or `nil`
        /// for `.system` (which removes the key entirely).
        private var code: String? {
            switch self {
            case .system:  return nil
            case .english: return "en"
            case .czech:   return "cs"
            }
        }

        /// The currently active override, read from the app's own defaults domain
        /// (not the resolved system list) so `.system` is detected accurately.
        static var current: AppLanguage {
            let bundleID = Bundle.main.bundleIdentifier ?? ""
            let domain = UserDefaults.standard.persistentDomain(forName: bundleID)
            guard let langs = domain?["AppleLanguages"] as? [String],
                  let first = langs.first else {
                return .system
            }
            if first.hasPrefix("cs") { return .czech }
            if first.hasPrefix("en") { return .english }
            return .system
        }

        /// Persists this choice. The change is picked up on the next launch.
        func apply() {
            let defaults = UserDefaults.standard
            if let code {
                defaults.set([code], forKey: "AppleLanguages")
            } else {
                defaults.removeObject(forKey: "AppleLanguages")
            }
        }
    }

    /// Terminal command that dumps the last 30 minutes of Vitals' unified logs.
    /// Kept in sync with the Troubleshooting section of the README.
    private let logCommand =
        "log show --predicate 'subsystem == \"com.filiphajduch.vitals\"' --info --debug --last 30m"

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

            Section {
                Picker("Language", selection: $language) {
                    Text("System").tag(AppLanguage.system)
                    Text(verbatim: "English").tag(AppLanguage.english)
                    Text(verbatim: "Čeština").tag(AppLanguage.czech)
                }
                .onChange(of: language) { _, newValue in
                    newValue.apply()
                }

                HStack {
                    Text("Takes effect after relaunch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        relaunchApp()
                    } label: {
                        Text("Relaunch Now")
                    }
                    .controlSize(.small)
                }
            } header: {
                Label("Language", systemImage: "globe")
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
                Picker("Refresh every", selection: Binding(
                    get: { appState.batterySavingInterval },
                    set: { appState.batterySavingInterval = $0 }
                )) {
                    Text("3s").tag(3.0)
                    Text("5s").tag(5.0)
                    Text("10s").tag(10.0)
                    Text("15s").tag(15.0)
                }
                .pickerStyle(.segmented)
            } header: {
                HStack(spacing: 4) {
                    Text("Battery Saving Interval")
                    Button {
                        showBatteryInfo.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .popover(isPresented: $showBatteryInfo, arrowEdge: .bottom) {
                        Text("When your Mac is unplugged and running on battery, Vitals automatically switches to this longer refresh interval and reduces expensive sensor reads to save energy.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(12)
                            .frame(width: 240)
                    }
                }
            } footer: {
                HStack(spacing: 4) {
                    Image(systemName: appState.powerMonitor.isOnBattery ? "battery.50percent" : "powerplug.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(appState.powerMonitor.isOnBattery ? .orange : .green)
                    Text(appState.powerMonitor.isOnBattery
                         ? LocalizedStringKey("On battery — saving mode active")
                         : LocalizedStringKey("On AC power — full performance"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

            Section {
                Toggle("Show public IP (queries api.ipify.org)", isOn: Binding(
                    get: { appState.enablePublicIPLookup },
                    set: { appState.enablePublicIPLookup = $0 }
                ))
            } header: {
                Label("Privacy", systemImage: "hand.raised")
            } footer: {
                Text("When enabled, Vitals sends an HTTPS request to the external service api.ipify.org to look up your public IP address. Off by default.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("App", value: "Vitals")
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                LabeledContent("Author", value: "Filip Hajduch")
                if let repoURL = URL(string: "https://github.com/filiphajduch420/Vitals") {
                    HStack {
                        Text("GitHub")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Link("filiphajduch420/Vitals", destination: repoURL)
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        checkForUpdates()
                    } label: {
                        Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.borderless)
                    .disabled(updateState == .checking)

                    updateStatusView
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Something not working — widgets show no data, a sensor reads zero? Copy this command and run it in Terminal to see the last 30 minutes of Vitals logs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        copyLogCommand()
                    } label: {
                        Label(
                            copiedLogCommand ? LocalizedStringKey("Copied!") : LocalizedStringKey("Copy log command"),
                            systemImage: copiedLogCommand ? "checkmark" : "doc.on.doc"
                        )
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private var updateStatusView: some View {
        switch updateState {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .upToDate:
            Label("Up to date", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case let .updateAvailable(version, url):
            Link(destination: url) {
                Label("Update available: \(version)", systemImage: "arrow.down.circle.fill")
                    .font(.caption)
            }
        case .failed:
            Label("Could not check for updates", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Runs only on an explicit tap — no automatic/background checks.
    private func checkForUpdates() {
        updateState = .checking
        Task { @MainActor in
            do {
                let result = try await UpdateChecker().checkForUpdate()
                switch result {
                case .upToDate:
                    updateState = .upToDate
                case let .updateAvailable(version, url):
                    updateState = .updateAvailable(version: version, url: url)
                }
            } catch {
                // The checker already logged the specific failure via VitalsLog.app.
                updateState = .failed
            }
        }
    }

    private func copyLogCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logCommand, forType: .string)
        copiedLogCommand = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            copiedLogCommand = false
        }
    }

    /// Relaunches Vitals so a new language override takes effect. Spawns a fresh
    /// instance of our own bundle (the `open -n` equivalent) and then terminates
    /// only this process — never touches any other running app.
    private func relaunchApp() {
        let bundleURL = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { _, error in
            if let error {
                VitalsLog.app.error("relaunch failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            Task { @MainActor in
                NSApp.terminate(nil)
            }
        }
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
            appState.barGPU = false
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

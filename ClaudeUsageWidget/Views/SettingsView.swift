import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var viewModel: UsageViewModel
    @State private var launchAtLogin = false

    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("notifySessionAt") private var notifySessionAt = 80
    @AppStorage("notifyWeekAt") private var notifyWeekAt = 75
    @AppStorage("notifyExtraAt") private var notifyExtraAt = 75
    @AppStorage("notifySessionEnabled") private var notifySessionEnabled = true
    @AppStorage("notifyWeekEnabled") private var notifyWeekEnabled = true
    @AppStorage("notifyExtraEnabled") private var notifyExtraEnabled = true

    private let intervals: [(label: String, value: TimeInterval)] = [
        ("1 minute", 60),
        ("2 minutes", 120),
        ("5 minutes", 300),
        ("10 minutes", 600),
        ("15 minutes", 900),
    ]

    private let thresholdOptions = [50, 60, 70, 75, 80, 85, 90, 95]

    var body: some View {
        Form {
            Section("Refresh") {
                Picker("Refresh interval", selection: $viewModel.refreshInterval) {
                    ForEach(intervals, id: \.value) { interval in
                        Text(interval.label).tag(interval.value)
                    }
                }
            }

            Section("Menu Bar") {
                Picker("Display mode", selection: $viewModel.menuBarDisplayMode) {
                    ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
            }

            Section {
                Toggle("Enable notifications", isOn: $notificationsEnabled)

                if notificationsEnabled {
                    notificationRow(
                        label: "Session limit",
                        enabled: $notifySessionEnabled,
                        threshold: $notifySessionAt
                    )
                    notificationRow(
                        label: "Weekly limit",
                        enabled: $notifyWeekEnabled,
                        threshold: $notifyWeekAt
                    )
                    notificationRow(
                        label: "Extra usage",
                        enabled: $notifyExtraEnabled,
                        threshold: $notifyExtraAt
                    )
                }
            } header: {
                Text("Notifications")
            }

            Section("System") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 500)
        .onAppear {
            if #available(macOS 13.0, *) {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    private func notificationRow(
        label: String,
        enabled: Binding<Bool>,
        threshold: Binding<Int>
    ) -> some View {
        VStack(spacing: 4) {
            HStack {
                Toggle(label, isOn: enabled)
                Spacer()
                if enabled.wrappedValue {
                    Text("at")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Picker("", selection: threshold) {
                        ForEach(thresholdOptions, id: \.self) { pct in
                            Text("\(pct)%").tag(pct)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 70)
                }
            }
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                launchAtLogin = false
            }
        }
    }
}

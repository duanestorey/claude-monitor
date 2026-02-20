import SwiftUI

@main
struct ClaudeUsageWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Settings", id: "settings") {
            SettingsView(viewModel: appDelegate.viewModel)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 500)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = UsageViewModel()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register defaults so NotificationService reads the same values as @AppStorage
        UserDefaults.standard.register(defaults: [
            "notificationsEnabled": true,
            "notifySessionEnabled": true,
            "notifySessionAt": 80,
            "notifyWeekEnabled": true,
            "notifyWeekAt": 75,
            "notifyExtraEnabled": true,
            "notifyExtraAt": 75,
        ])

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover.contentSize = NSSize(width: 320, height: 600)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: MainPopoverView(viewModel: viewModel)
        )

        updateButton()

        // Observe changes to update the button
        viewModel.$usage
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateButton() }
            .store(in: &cancellables)
        viewModel.$menuBarDisplayMode
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateButton() }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    private func updateButton() {
        guard let button = statusItem.button else { return }

        let pct = viewModel.mostConstrainedPercent
        let iconName: String
        if pct >= 90 { iconName = "gauge.with.dots.needle.100percent" }
        else if pct >= 60 { iconName = "gauge.with.dots.needle.67percent" }
        else if pct >= 30 { iconName = "gauge.with.dots.needle.50percent" }
        else if pct > 0 { iconName = "gauge.with.dots.needle.33percent" }
        else { iconName = "gauge.with.dots.needle.0percent" }

        let text = viewModel.menuBarText

        if text.isEmpty {
            // Icon only
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Claude Usage")
            button.attributedTitle = NSAttributedString(string: "")
            button.imagePosition = .imageOnly
        } else {
            // Icon + colored text
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Claude Usage")
            button.imagePosition = .imageLeading

            let sessionPct = viewModel.usage?.fiveHour?.utilization ?? 0
            let color: NSColor
            if sessionPct >= 90 { color = .systemRed }
            else if sessionPct >= 70 { color = .systemOrange }
            else { color = .systemGreen }

            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: color
            ]
            button.attributedTitle = NSAttributedString(string: " \(text)", attributes: attrs)
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Make the popover's window key so .transient dismiss-on-outside-click works
            popover.contentViewController?.view.window?.makeKey()
            // Refresh data when opening
            Task {
                await viewModel.refreshIfStale()
            }
        }
    }
}

import Combine

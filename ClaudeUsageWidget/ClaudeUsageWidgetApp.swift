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
        .defaultPosition(.center)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let _registerDefaults: Void = {
        UserDefaults.standard.register(defaults: [
            "notificationsEnabled": true,
            "notifySessionEnabled": true,
            "notifySessionAt": 80,
            "notifyWeekEnabled": true,
            "notifyWeekAt": 75,
            "notifyExtraEnabled": true,
            "notifyExtraAt": 75,
        ])
    }()

    let viewModel: UsageViewModel = {
        _ = AppDelegate._registerDefaults
        return UsageViewModel()
    }()

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide any windows SwiftUI opens automatically — this is a menu-bar-only app
        for window in NSApp.windows {
            window.orderOut(nil)
        }

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

        let attributed = menuBarAttributedText()

        if attributed.length == 0 {
            // Icon only
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Claude Usage")
            button.attributedTitle = NSAttributedString(string: "")
            button.imagePosition = .imageOnly
        } else {
            // Icon + colored text
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Claude Usage")
            button.imagePosition = .imageLeading
            button.attributedTitle = attributed
        }
    }

    private func colorForUtilization(_ pct: Double) -> NSColor {
        if pct >= 90 { return .systemRed }
        if pct >= 70 { return .systemOrange }
        return .systemGreen
    }

    private func menuBarAttributedText() -> NSAttributedString {
        guard let usage = viewModel.usage else { return NSAttributedString(string: "") }
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)

        switch viewModel.menuBarDisplayMode {
        case .iconOnly:
            return NSAttributedString(string: "")

        case .sessionPercent:
            let pct = usage.fiveHour?.utilization ?? 0
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: colorForUtilization(pct)]
            return NSAttributedString(string: " \(Int(pct))%", attributes: attrs)

        case .weekPercent:
            let pct = usage.sevenDay?.utilization ?? 0
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: colorForUtilization(pct)]
            return NSAttributedString(string: " \(Int(pct))%", attributes: attrs)

        case .bothPercents:
            let sPct = usage.fiveHour?.utilization ?? 0
            let wPct = usage.sevenDay?.utilization ?? 0
            let result = NSMutableAttributedString()
            result.append(NSAttributedString(string: " \(Int(sPct))%",
                attributes: [.font: font, .foregroundColor: colorForUtilization(sPct)]))
            result.append(NSAttributedString(string: " · ",
                attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor]))
            result.append(NSAttributedString(string: "\(Int(wPct))%",
                attributes: [.font: font, .foregroundColor: colorForUtilization(wPct)]))
            return result
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

import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var viewModel: UsageViewModel

    private var sessionPercent: Double {
        viewModel.usage?.fiveHour?.utilization ?? 0
    }

    private var iconName: String {
        let pct = viewModel.mostConstrainedPercent
        if pct >= 90 { return "gauge.with.dots.needle.100percent" }
        if pct >= 60 { return "gauge.with.dots.needle.67percent" }
        if pct >= 30 { return "gauge.with.dots.needle.50percent" }
        if pct > 0 { return "gauge.with.dots.needle.33percent" }
        return "gauge.with.dots.needle.0percent"
    }

    private var iconColor: Color {
        if sessionPercent >= 90 { return .red }
        if sessionPercent >= 70 { return .orange }
        return .green
    }

    var body: some View {
        let text = viewModel.menuBarText
        if text.isEmpty {
            Label {
                Text("Claude Usage")
            } icon: {
                Image(systemName: iconName)
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(iconColor)
            }
        } else {
            Label {
                Text(text)
            } icon: {
                Image(systemName: iconName)
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(iconColor)
            }
        }
    }
}

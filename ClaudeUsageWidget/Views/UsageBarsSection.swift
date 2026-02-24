import SwiftUI

struct UsageBarsSection: View {
    let usage: UsageResponse

    var body: some View {
        VStack(spacing: 12) {
            if let fiveHour = usage.fiveHour {
                UsageBarView(
                    title: "Session (5h)",
                    utilization: fiveHour.utilization,
                    subtitle: resetLabel(fiveHour)
                )
            }

            if let sevenDay = usage.sevenDay {
                UsageBarView(
                    title: "Week — All Models (7d)",
                    utilization: sevenDay.utilization,
                    subtitle: resetLabel(sevenDay)
                )
            }

            if let sonnet = usage.sevenDaySonnet {
                UsageBarView(
                    title: "Week — Sonnet Only (7d)",
                    utilization: sonnet.utilization,
                    subtitle: resetLabel(sonnet)
                )
            }

            if let extra = usage.extraUsage, extra.enabled {
                UsageBarView(
                    title: "Extra Usage",
                    utilization: extra.effectiveUtilization,
                    subtitle: String(format: "$%.2f / $%.2f spent", extra.usedDollars, extra.limitDollars)
                )
            }
        }
    }

    private func resetLabel(_ limit: UsageLimit) -> String {
        guard let date = limit.resetsAtDate else {
            if let raw = limit.resetsAt { return "Resets at \(raw)" }
            return "Reset time unknown"
        }

        let now = Date()
        let interval = date.timeIntervalSince(now)

        if interval <= 0 {
            return "Resetting..."
        }

        if interval < 3600 {
            let mins = Int(interval / 60)
            return "Resets in \(mins)m"
        }

        if interval < 86400 {
            let hours = Int(interval / 3600)
            let mins = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            return "Resets in \(hours)h \(mins)m"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d 'at' h:mm a"
        return "Resets \(formatter.string(from: date))"
    }
}

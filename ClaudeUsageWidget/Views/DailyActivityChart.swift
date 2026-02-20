import SwiftUI
import Charts

@available(macOS 13.0, *)
struct DailyActivityChart: View {
    let activities: [DailyActivity]

    private var recentActivities: [DailyActivity] {
        Array(activities.suffix(7))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Daily Activity (Last 7 Days)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            if recentActivities.isEmpty {
                Text("No activity data")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                Chart(recentActivities) { activity in
                    BarMark(
                        x: .value("Date", activity.shortDateLabel),
                        y: .value("Messages", activity.messageCount ?? 0)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(2)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                        AxisValueLabel()
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        AxisGridLine()
                            .foregroundStyle(.secondary.opacity(0.2))
                    }
                }
                .frame(height: 80)
            }
        }
    }
}

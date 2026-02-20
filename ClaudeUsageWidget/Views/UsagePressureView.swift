import SwiftUI

struct UsagePressureView: View {
    let usage: UsageResponse

    /// Positive = under budget (green, bar goes right)
    /// Negative = over budget (red, bar goes left)
    private var pressure: Double {
        guard let sevenDay = usage.sevenDay,
              let resetsAt = sevenDay.resetsAtDate else { return 0 }

        let now = Date()
        let secondsRemaining = resetsAt.timeIntervalSince(now)
        let totalSeconds: Double = 7 * 24 * 3600
        let secondsElapsed = totalSeconds - secondsRemaining

        guard secondsElapsed > 0, secondsRemaining > 0 else { return 0 }

        let expectedUtilization = (secondsElapsed / totalSeconds) * 100.0
        return expectedUtilization - sevenDay.utilization
    }

    private var statusLabel: String {
        let p = pressure
        if abs(p) < 3 { return "On Track" }
        if p > 0 {
            if p > 15 { return "Well Under Budget" }
            return "Under Budget"
        } else {
            if p < -15 { return "Heavy Usage" }
            return "Over Budget"
        }
    }

    private var statusColor: Color {
        let p = pressure
        if abs(p) < 3 { return .blue }
        return p > 0 ? .green : .red
    }

    private var statusIcon: String {
        let p = pressure
        if abs(p) < 3 { return "gauge.with.dots.needle.50percent" }
        return p > 0 ? "gauge.with.dots.needle.33percent" : "gauge.with.dots.needle.67percent"
    }

    var body: some View {
        let p = pressure

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: statusIcon)
                    .font(.system(size: 12))
                    .foregroundColor(statusColor)

                Text("Weekly Pace")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                Text(statusLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(statusColor)
            }

            // Centered bar gauge
            GeometryReader { geo in
                let midX = geo.size.width / 2
                // Clamp to -50...+50 for display, map to half-width
                let clamped = max(-50, min(50, p))
                let barWidth = abs(clamped) / 50.0 * midX

                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)

                    // Center tick marks for reference
                    ForEach([0.25, 0.5, 0.75], id: \.self) { frac in
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 1, height: 8)
                            .offset(x: geo.size.width * frac)
                    }

                    // Center line
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 1.5, height: 12)
                        .offset(x: midX - 0.75)

                    // Pressure bar
                    if clamped >= 0 {
                        // Green bar going right from center
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barGradient(for: clamped))
                            .frame(width: max(2, barWidth), height: 8)
                            .offset(x: midX)
                    } else {
                        // Red bar going left from center
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barGradient(for: clamped))
                            .frame(width: max(2, barWidth), height: 8)
                            .offset(x: midX - barWidth)
                    }
                }
            }
            .frame(height: 12)

            // Legend
            HStack {
                Text("Over")
                    .font(.system(size: 9))
                    .foregroundColor(.red.opacity(0.5))
                Spacer()
                let sign = p >= 0 ? "+" : ""
                Text("\(sign)\(Int(p))% vs expected")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.6))
                Spacer()
                Text("Under")
                    .font(.system(size: 9))
                    .foregroundColor(.green.opacity(0.5))
            }
        }
    }

    private func barGradient(for value: Double) -> LinearGradient {
        if value >= 0 {
            return LinearGradient(
                colors: [.green.opacity(0.7), .green],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            let severity = min(abs(value) / 30.0, 1.0)
            let color: Color = severity > 0.5 ? .red : .orange
            return LinearGradient(
                colors: [color, color.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

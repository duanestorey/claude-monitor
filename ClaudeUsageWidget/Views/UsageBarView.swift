import SwiftUI

struct UsageBarView: View {
    let title: String
    let utilization: Double
    let subtitle: String
    let detail: String?

    init(title: String, utilization: Double, subtitle: String, detail: String? = nil) {
        self.title = title
        self.utilization = utilization
        self.subtitle = subtitle
        self.detail = detail
    }

    private var barColor: Color {
        if utilization >= 90 { return .red }
        if utilization >= 70 { return .orange }
        return .green
    }

    private var percentText: String {
        "\(Int(utilization))% used"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: max(0, geo.size.width * CGFloat(min(utilization, 100)) / 100), height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text(percentText)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                if let detail = detail {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.7))
        }
    }
}

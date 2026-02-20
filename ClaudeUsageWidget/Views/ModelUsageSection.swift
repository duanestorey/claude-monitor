import SwiftUI

struct ModelUsageSection: View {
    let modelUsage: [String: ModelTokenUsage]

    private var sortedModels: [(name: String, usage: ModelTokenUsage)] {
        modelUsage.map { (name: $0.key, usage: $0.value) }
            .sorted { ($0.usage.outputTokens ?? 0) > ($1.usage.outputTokens ?? 0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Model Usage")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            ForEach(sortedModels, id: \.name) { model in
                HStack {
                    Text(shortModelName(model.name))
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .frame(width: 80, alignment: .leading)

                    Spacer()

                    let output = model.usage.outputTokens ?? 0
                    let cache = (model.usage.cacheReadInputTokens ?? 0) + (model.usage.cacheCreationInputTokens ?? 0)

                    Text("\(formatTokens(output)) out")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)

                    Text("·")
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("\(formatTokens(cache)) cache")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func shortModelName(_ name: String) -> String {
        if name.contains("opus") { return "Opus 4.6" }
        if name.contains("sonnet") && name.contains("4-5") { return "Sonnet 4.5" }
        if name.contains("sonnet") { return "Sonnet" }
        if name.contains("haiku") { return "Haiku 4.5" }
        return name
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            let value = Double(count) / 1_000_000.0
            return String(format: "%.1fM", value)
        }
        if count >= 1_000 {
            let value = Double(count) / 1_000.0
            if value >= 100 {
                return String(format: "%.0fK", value)
            }
            return String(format: "%.1fK", value)
        }
        return "\(count)"
    }
}

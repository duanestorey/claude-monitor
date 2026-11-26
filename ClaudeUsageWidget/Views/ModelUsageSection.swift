import SwiftUI

struct ModelUsageSection: View {
    let modelUsage: [String: ModelTokenUsage]
    /// Start of the retained transcript window (Claude Code prunes old sessions).
    let since: Date?

    private var title: String {
        guard let since = since else { return "Model Usage" }
        return "Model Usage (since \(since.formatted(.dateTime.month(.abbreviated).day())))"
    }

    private var sortedModels: [(name: String, usage: ModelTokenUsage)] {
        modelUsage.map { (name: $0.key, usage: $0.value) }
            .sorted { $0.usage.outputTokens > $1.usage.outputTokens }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            ForEach(sortedModels, id: \.name) { model in
                HStack {
                    Text(ModelNameFormatter.displayName(for: model.name))
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .frame(width: 80, alignment: .leading)

                    Spacer()

                    let output = model.usage.outputTokens
                    let cache = model.usage.cacheReadInputTokens + model.usage.cacheCreationInputTokens

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

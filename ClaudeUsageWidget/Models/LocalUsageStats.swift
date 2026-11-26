import Foundation

/// Local usage statistics aggregated from Claude Code's session transcripts
/// (`~/.claude/projects/**/*.jsonl`). Claude Code prunes old transcripts
/// (default ~30 days), so totals cover the retained window, not all time.
struct LocalUsageStats {
    /// One entry per calendar day (local time), oldest first, zero-filled.
    let dailyActivity: [DailyActivity]
    /// Keyed by raw model ID (e.g. `claude-opus-5-5`).
    let modelUsage: [String: ModelTokenUsage]
    let totalSessions: Int
    let totalMessages: Int
    /// Earliest transcript activity found — the start of the retained window.
    let earliestActivity: Date?
}

struct DailyActivity: Identifiable {
    let date: Date          // start of day, local time
    let messageCount: Int
    let sessionCount: Int
    let toolCallCount: Int

    var id: Date { date }

    var shortDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

struct ModelTokenUsage {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadInputTokens: Int = 0
    var cacheCreationInputTokens: Int = 0
    var webSearchRequests: Int = 0
}

enum ModelNameFormatter {
    /// `claude-opus-5-5` → "Opus 5.5", `claude-sonnet-4-5-20250929` → "Sonnet 4.5",
    /// `claude-3-5-haiku-20241022` → "Haiku 3.5".
    static func displayName(for modelID: String) -> String {
        var parts = modelID.split(separator: "-").map(String.init)
        if parts.first == "claude" { parts.removeFirst() }
        // Drop a trailing date stamp like 20250929
        if let last = parts.last, last.count == 8, Int(last) != nil { parts.removeLast() }

        let words = parts.filter { Int($0) == nil }
        let numbers = parts.filter { Int($0) != nil }
        guard !words.isEmpty else { return modelID }

        let family = words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
        return numbers.isEmpty ? family : "\(family) \(numbers.joined(separator: "."))"
    }
}

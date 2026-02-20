import Foundation

struct StatsCache: Codable {
    let version: Int?
    let lastComputedDate: String?
    let dailyActivity: [DailyActivity]?
    let dailyModelTokens: [DailyModelTokens]?
    let modelUsage: [String: ModelTokenUsage]?
    let totalSessions: Int?
    let totalMessages: Int?
    let longestSession: LongestSession?
    let firstSessionDate: String?
}

struct DailyActivity: Codable, Identifiable {
    let date: String
    let messageCount: Int?
    let sessionCount: Int?
    let toolCallCount: Int?

    var id: String { date }

    var dateValue: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: date)
    }

    var shortDateLabel: String {
        guard let d = dateValue else { return date }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: d)
    }
}

struct DailyModelTokens: Codable {
    let date: String
    let tokensByModel: [String: Int]?
}

struct ModelTokenUsage: Codable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheReadInputTokens: Int?
    let cacheCreationInputTokens: Int?
    let webSearchRequests: Int?
}

struct LongestSession: Codable {
    let sessionId: String?
    let duration: Int?
    let messageCount: Int?
    let timestamp: String?
}

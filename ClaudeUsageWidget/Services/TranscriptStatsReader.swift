import Foundation
import CoreServices

/// Builds `LocalUsageStats` from Claude Code's session transcripts in
/// `~/.claude/projects/**/*.jsonl`.
///
/// Claude Code no longer keeps `~/.claude/stats-cache.json` up to date, so the
/// transcripts are the source of truth. Each line is a JSON event; assistant
/// events carry `message.model` and `message.usage`. A single API response is
/// written across several lines (one per content block) sharing `message.id`,
/// so responses are de-duplicated by that ID.
///
/// Parsing is cached per file (keyed on mtime + size), so only transcripts that
/// changed are re-read. Changes are picked up via an FSEvents stream on the
/// projects directory.
final class TranscriptStatsReader {
    static let shared = TranscriptStatsReader()

    /// Called on the main queue whenever a scan produces new stats.
    var onUpdate: ((LocalUsageStats) -> Void)?

    private let rootURL: URL
    private let queue = DispatchQueue(label: "TranscriptStatsReader", qos: .utility)
    private var cache: [String: FileSummary] = [:]   // accessed only on `queue`
    private var scanPending = false                  // accessed only on `queue`
    private var eventStream: FSEventStreamRef?

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        rootURL = home.appendingPathComponent(".claude/projects", isDirectory: true)
    }

    // MARK: - Public

    /// Schedules a background rescan; coalesces bursts of requests.
    func scheduleScan() {
        queue.async {
            guard !self.scanPending else { return }
            self.scanPending = true
            self.queue.async {
                self.scanPending = false
                let stats = self.scan()
                DispatchQueue.main.async { self.onUpdate?(stats) }
            }
        }
    }

    func startWatching() {
        stopWatching()

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info = info else { return }
            Unmanaged<TranscriptStatsReader>.fromOpaque(info).takeUnretainedValue().scheduleScan()
        }
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [rootURL.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            5.0, // latency: coalesce rapid transcript appends
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagNone)
        ) else { return }

        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        eventStream = stream
    }

    func stopWatching() {
        guard let stream = eventStream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        eventStream = nil
    }

    // MARK: - Scanning (on `queue`)

    private func scan() -> LocalUsageStats {
        var seenPaths = Set<String>()

        if let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let url as URL in enumerator where url.pathExtension == "jsonl" {
                guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]),
                      values.isRegularFile == true else { continue }
                let path = url.path
                let modified = values.contentModificationDate ?? .distantPast
                let size = values.fileSize ?? 0
                seenPaths.insert(path)

                if let cached = cache[path], cached.modified == modified, cached.size == size { continue }
                cache[path] = parseFile(url, modified: modified, size: size)
            }
        }

        // Drop transcripts Claude Code has cleaned up
        cache = cache.filter { seenPaths.contains($0.key) }

        return aggregate()
    }

    private func parseFile(_ url: URL, modified: Date, size: Int) -> FileSummary {
        var summary = FileSummary(modified: modified, size: size)
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return summary }

        for line in data.split(separator: UInt8(ascii: "\n")) {
            guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let type = obj["type"] as? String,
                  type == "assistant" || type == "user",
                  let timestamp = obj["timestamp"] as? String,
                  let date = Self.parseTimestamp(timestamp) else { continue }

            let sessionId = obj["sessionId"] as? String ?? url.deletingPathExtension().lastPathComponent
            let day = Calendar.current.startOfDay(for: date)

            if type == "user" {
                // Count real prompts only — skip meta events and tool results
                if obj["isMeta"] as? Bool == true || obj["toolUseResult"] != nil { continue }
                if let blocks = (obj["message"] as? [String: Any])?["content"] as? [[String: Any]],
                   blocks.contains(where: { $0["type"] as? String == "tool_result" }) { continue }
                guard let uuid = obj["uuid"] as? String else { continue }
                summary.userMessages[uuid] = Activity(day: day, sessionId: sessionId)
                continue
            }

            guard let message = obj["message"] as? [String: Any],
                  let messageID = message["id"] as? String,
                  let model = message["model"] as? String,
                  !model.hasPrefix("<") else { continue } // skip "<synthetic>"

            var response = summary.responses[messageID]
                ?? Response(day: day, sessionId: sessionId, model: model)

            if let usage = message["usage"] as? [String: Any] {
                // Every line of a response repeats the usage; later lines are the most complete.
                response.usage = ModelTokenUsage(
                    inputTokens: usage["input_tokens"] as? Int ?? 0,
                    outputTokens: usage["output_tokens"] as? Int ?? 0,
                    cacheReadInputTokens: usage["cache_read_input_tokens"] as? Int ?? 0,
                    cacheCreationInputTokens: usage["cache_creation_input_tokens"] as? Int ?? 0,
                    webSearchRequests: (usage["server_tool_use"] as? [String: Any])?["web_search_requests"] as? Int ?? 0
                )
            }

            if let content = message["content"] as? [[String: Any]] {
                for block in content where block["type"] as? String == "tool_use" {
                    if let id = block["id"] as? String { response.toolUseIDs.insert(id) }
                }
            }

            summary.responses[messageID] = response
        }
        return summary
    }

    private func aggregate() -> LocalUsageStats {
        // De-duplicate across files (resumed sessions can repeat earlier events)
        var responses: [String: Response] = [:]
        var users: [String: Activity] = [:]
        for summary in cache.values {
            responses.merge(summary.responses) { existing, _ in existing }
            users.merge(summary.userMessages) { existing, _ in existing }
        }

        var messagesByDay: [Date: Int] = [:]
        var toolCallsByDay: [Date: Int] = [:]
        var sessionsByDay: [Date: Set<String>] = [:]
        var allSessions = Set<String>()
        var modelUsage: [String: ModelTokenUsage] = [:]

        for r in responses.values {
            messagesByDay[r.day, default: 0] += 1
            toolCallsByDay[r.day, default: 0] += r.toolUseIDs.count
            sessionsByDay[r.day, default: []].insert(r.sessionId)
            allSessions.insert(r.sessionId)

            var m = modelUsage[r.model] ?? ModelTokenUsage()
            m.inputTokens += r.usage.inputTokens
            m.outputTokens += r.usage.outputTokens
            m.cacheReadInputTokens += r.usage.cacheReadInputTokens
            m.cacheCreationInputTokens += r.usage.cacheCreationInputTokens
            m.webSearchRequests += r.usage.webSearchRequests
            modelUsage[r.model] = m
        }
        for u in users.values {
            messagesByDay[u.day, default: 0] += 1
            sessionsByDay[u.day, default: []].insert(u.sessionId)
            allSessions.insert(u.sessionId)
        }

        // Zero-filled daily series from the earliest activity (or 7 days ago) through today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -6, to: today)!
        let earliest = messagesByDay.keys.min()
        var day = min(earliest ?? weekAgo, weekAgo)
        var daily: [DailyActivity] = []
        while day <= today {
            daily.append(DailyActivity(
                date: day,
                messageCount: messagesByDay[day] ?? 0,
                sessionCount: sessionsByDay[day]?.count ?? 0,
                toolCallCount: toolCallsByDay[day] ?? 0
            ))
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }

        return LocalUsageStats(
            dailyActivity: daily,
            modelUsage: modelUsage,
            totalSessions: allSessions.count,
            totalMessages: messagesByDay.values.reduce(0, +),
            earliestActivity: earliest
        )
    }

    // MARK: - Helpers

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain = ISO8601DateFormatter()

    private static func parseTimestamp(_ s: String) -> Date? {
        isoFractional.date(from: s) ?? isoPlain.date(from: s)
    }
}

// MARK: - Per-file cache types

private struct FileSummary {
    let modified: Date
    let size: Int
    var responses: [String: Response] = [:]     // keyed by message.id
    var userMessages: [String: Activity] = [:]  // keyed by event uuid
}

private struct Response {
    let day: Date
    let sessionId: String
    let model: String
    var usage = ModelTokenUsage()
    var toolUseIDs = Set<String>()
}

private struct Activity {
    let day: Date
    let sessionId: String
}

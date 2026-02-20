import Foundation

final class StatsCacheReader {
    static let shared = StatsCacheReader()

    private let filePath: String
    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?

    var onChange: (() -> Void)?

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.filePath = "\(home)/.claude/stats-cache.json"
    }

    func read() -> StatsCache? {
        let url = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: filePath),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(StatsCache.self, from: data)
    }

    func startWatching() {
        stopWatching()

        let fd = open(filePath, O_EVTONLY)
        guard fd >= 0 else { return }
        fileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let flags = source.data
            self.onChange?()

            // File was renamed or deleted (atomic write by Claude Code) — restart watcher
            if flags.contains(.rename) || flags.contains(.delete) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.startWatching()
                }
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        dispatchSource = source
    }

    func stopWatching() {
        dispatchSource?.cancel()
        dispatchSource = nil
        fileDescriptor = -1
    }
}

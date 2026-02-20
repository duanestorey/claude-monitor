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

        fileDescriptor = open(filePath, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.onChange?()
        }

        source.setCancelHandler { [weak self] in
            guard let self = self, self.fileDescriptor >= 0 else { return }
            close(self.fileDescriptor)
            self.fileDescriptor = -1
        }

        source.resume()
        dispatchSource = source
    }

    func stopWatching() {
        dispatchSource?.cancel()
        dispatchSource = nil
    }
}

import Foundation
import Combine
import AppKit

enum AppError: Equatable {
    case keychainNotFound
    case authExpired
    case networkError(String)
    case rateLimited

    static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case (.keychainNotFound, .keychainNotFound): return true
        case (.authExpired, .authExpired): return true
        case (.networkError(let a), .networkError(let b)): return a == b
        case (.rateLimited, .rateLimited): return true
        default: return false
        }
    }

    var message: String {
        switch self {
        case .keychainNotFound:
            return "Claude Code not installed or not logged in"
        case .authExpired:
            return "Auth expired — run Claude Code to refresh"
        case .networkError(let msg):
            return msg
        case .rateLimited:
            return "Rate limited — will retry shortly"
        }
    }
}

@MainActor
final class UsageViewModel: ObservableObject {
    // MARK: - Published State

    @Published var usage: UsageResponse?
    @Published var profile: ProfileResponse?
    @Published var stats: StatsCache?
    @Published var error: AppError?
    @Published var lastUpdated: Date?
    @Published var isLoading = false

    // MARK: - Settings

    @Published var refreshInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
            restartTimer()
        }
    }

    @Published var menuBarDisplayMode: MenuBarDisplayMode {
        didSet {
            UserDefaults.standard.set(menuBarDisplayMode.rawValue, forKey: "menuBarDisplayMode")
        }
    }

    // MARK: - Private

    private var pollTimer: Timer?
    private var authRetryTimer: Timer?
    private let authRetryInterval: TimeInterval = 30 // Check keychain every 30s when auth is expired
    private var backoffMultiplier: Double = 1.0
    private let maxBackoffInterval: TimeInterval = 30 * 60
    private var workspaceObservers: [NSObjectProtocol] = []

    // MARK: - Init

    init() {
        let saved = UserDefaults.standard.double(forKey: "refreshInterval")
        self.refreshInterval = saved > 0 ? saved : 300

        let modeRaw = UserDefaults.standard.string(forKey: "menuBarDisplayMode") ?? MenuBarDisplayMode.iconOnly.rawValue
        self.menuBarDisplayMode = MenuBarDisplayMode(rawValue: modeRaw) ?? .iconOnly

        setupStatsWatcher()
        setupWorkspaceObservers()
        NotificationService.shared.requestPermission()

        Task {
            await refresh()
            startTimer()
        }
    }

    deinit {
        pollTimer?.invalidate()
        authRetryTimer?.invalidate()
        StatsCacheReader.shared.stopWatching()
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    // MARK: - Public

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        // Read keychain
        let credentials: KeychainCredentials
        do {
            credentials = try await KeychainService.shared.readCredentials()
        } catch is KeychainError {
            self.error = .keychainNotFound
            return
        } catch {
            self.error = .keychainNotFound
            return
        }

        // Check token expiry — if expired, start fast-polling the keychain
        if credentials.claudeAiOauth.isExpiringSoon {
            self.error = .authExpired
            startAuthRetryTimer()
            return
        }

        // Token is valid — clear any stale auth error and stop fast-polling
        if self.error == .authExpired {
            self.error = nil
        }
        stopAuthRetryTimer()

        let token = credentials.claudeAiOauth.accessToken

        // Fetch usage and profile concurrently
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchUsage(token: token) }
            group.addTask { await self.fetchProfile(token: token) }
        }

        // Read stats
        self.stats = StatsCacheReader.shared.read()

        // Check notification thresholds
        if let usage = self.usage {
            NotificationService.shared.checkAndNotify(usage: usage)
        }

        if self.error == nil {
            self.lastUpdated = Date()
            self.backoffMultiplier = 1.0
        }
    }

    func refreshIfStale() async {
        guard let last = lastUpdated else {
            await refresh()
            return
        }
        if Date().timeIntervalSince(last) > 60 {
            await refresh()
        }
    }

    // MARK: - Computed

    var menuBarText: String {
        guard let usage = usage else { return "" }
        switch menuBarDisplayMode {
        case .iconOnly:
            return ""
        case .sessionPercent:
            if let five = usage.fiveHour {
                return "\(Int(five.utilization))%"
            }
            return ""
        case .weekPercent:
            if let seven = usage.sevenDay {
                return "\(Int(seven.utilization))%"
            }
            return ""
        case .bothPercents:
            let s = usage.fiveHour.map { "\(Int($0.utilization))%" } ?? "--"
            let w = usage.sevenDay.map { "\(Int($0.utilization))%" } ?? "--"
            return "\(s) · \(w)"
        }
    }

    var mostConstrainedPercent: Double {
        guard let usage = usage else { return 0 }
        let values = [
            usage.fiveHour?.utilization,
            usage.sevenDay?.utilization,
            usage.extraUsage?.effectiveUtilization
        ].compactMap { $0 }
        return values.max() ?? 0
    }

    // MARK: - Private Methods

    private func fetchUsage(token: String) async {
        do {
            let result = try await AnthropicAPIClient.shared.fetchUsage(token: token)
            self.usage = result
            if self.error != nil {
                self.error = nil
            }
        } catch let apiError as APIError {
            switch apiError {
            case .unauthorized:
                await retryWithFreshToken()
            case .rateLimited(let retryAfter):
                self.error = .rateLimited
                let divisor = refreshInterval > 0 ? refreshInterval : 1.0
                self.backoffMultiplier = min(self.backoffMultiplier * 2, maxBackoffInterval / divisor)
                if let retry = retryAfter {
                    Task {
                        try? await Task.sleep(nanoseconds: UInt64(retry * 1_000_000_000))
                        await self.refresh()
                    }
                }
            default:
                self.error = .networkError(apiError.localizedDescription)
            }
        } catch {
            self.error = .networkError(error.localizedDescription)
        }
    }

    private func retryWithFreshToken() async {
        do {
            let creds = try await KeychainService.shared.readCredentials()
            if !creds.claudeAiOauth.isExpiringSoon {
                let result = try await AnthropicAPIClient.shared.fetchUsage(token: creds.claudeAiOauth.accessToken)
                self.usage = result
                self.error = nil
                return
            }
        } catch {}
        self.error = .authExpired
    }

    private func fetchProfile(token: String) async {
        do {
            let result = try await AnthropicAPIClient.shared.fetchProfile(token: token)
            self.profile = result
        } catch let apiError as APIError where apiError.isAuthError {
            // Auth errors handled in fetchUsage
        } catch {
            // Profile errors are non-critical
        }
    }

    private func startAuthRetryTimer() {
        guard authRetryTimer == nil else { return }
        authRetryTimer = Timer.scheduledTimer(withTimeInterval: authRetryInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.refresh()
            }
        }
    }

    private func stopAuthRetryTimer() {
        authRetryTimer?.invalidate()
        authRetryTimer = nil
    }

    private func startTimer() {
        restartTimer()
    }

    private func restartTimer() {
        pollTimer?.invalidate()
        let interval = refreshInterval * backoffMultiplier
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.refresh()
            }
        }
    }

    private func setupStatsWatcher() {
        StatsCacheReader.shared.onChange = { [weak self] in
            Task { @MainActor [weak self] in
                self?.stats = StatsCacheReader.shared.read()
            }
        }
        StatsCacheReader.shared.startWatching()
    }

    private func setupWorkspaceObservers() {
        let sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.pollTimer?.invalidate()
            }
        }

        let wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.refresh()
                self.restartTimer()
            }
        }

        workspaceObservers = [sleepObserver, wakeObserver]
    }
}

// MARK: - Supporting Types

enum MenuBarDisplayMode: String, CaseIterable {
    case iconOnly = "iconOnly"
    case sessionPercent = "sessionPercent"
    case weekPercent = "weekPercent"
    case bothPercents = "bothPercents"

    var label: String {
        switch self {
        case .iconOnly: return "Icon Only"
        case .sessionPercent: return "Session %"
        case .weekPercent: return "Week %"
        case .bothPercents: return "Session % + Week %"
        }
    }
}

extension AppError {
    var isRetryable: Bool {
        switch self {
        case .networkError, .rateLimited: return true
        default: return false
        }
    }
}

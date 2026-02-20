import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    // Track which notifications we've already sent this cycle to avoid spamming
    private var sentNotifications: Set<String> = []

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func checkAndNotify(usage: UsageResponse) {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "notificationsEnabled") else { return }

        // Session
        if defaults.bool(forKey: "notifySessionEnabled"), let session = usage.fiveHour {
            let threshold = defaults.integer(forKey: "notifySessionAt")
            if threshold > 0 {
                checkThreshold(
                    id: "session",
                    label: "Session",
                    value: session.utilization,
                    threshold: threshold,
                    resetKey: session.resetsAt
                )
            }
        }

        // Weekly
        if defaults.bool(forKey: "notifyWeekEnabled"), let week = usage.sevenDay {
            let threshold = defaults.integer(forKey: "notifyWeekAt")
            if threshold > 0 {
                checkThreshold(
                    id: "week",
                    label: "Weekly",
                    value: week.utilization,
                    threshold: threshold,
                    resetKey: week.resetsAt
                )
            }
        }

        // Extra usage
        if defaults.bool(forKey: "notifyExtraEnabled"),
           let extra = usage.extraUsage, extra.isEnabled {
            let threshold = defaults.integer(forKey: "notifyExtraAt")
            if threshold > 0 {
                checkThreshold(
                    id: "extra",
                    label: "Extra Usage",
                    value: extra.utilization,
                    threshold: threshold,
                    resetKey: "extra-\(extra.monthlyLimit)"
                )
            }
        }
    }

    /// Clear sent notifications when a usage period resets
    func clearIfReset(usage: UsageResponse) {
        if let session = usage.fiveHour, session.utilization < 5 {
            sentNotifications = sentNotifications.filter { !$0.hasPrefix("session") }
        }
        if let week = usage.sevenDay, week.utilization < 5 {
            sentNotifications = sentNotifications.filter { !$0.hasPrefix("week") }
        }
    }

    private func checkThreshold(id: String, label: String, value: Double, threshold: Int, resetKey: String) {
        let notifKey = "\(id)-\(threshold)-\(resetKey)"
        guard value >= Double(threshold), !sentNotifications.contains(notifKey) else { return }

        sentNotifications.insert(notifKey)
        send(
            title: "\(label) Usage at \(Int(value))%",
            body: "Your \(label.lowercased()) usage has reached \(threshold)% of the limit."
        )
    }

    private func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

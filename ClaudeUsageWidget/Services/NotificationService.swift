import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    // Track whether each category's notification has fired.
    // Once fired, it stays fired until usage drops below the threshold (re-arms).
    private var hasFired: Set<String> = []

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
                    threshold: threshold
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
                    threshold: threshold
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
                    threshold: threshold
                )
            }
        }
    }

    private func checkThreshold(id: String, label: String, value: Double, threshold: Int) {
        let notifKey = "\(id)-\(threshold)"

        if value < Double(threshold) {
            // Below threshold: re-arm so it can fire again next time we cross above
            hasFired.remove(notifKey)
            return
        }

        // At or above threshold: fire once, then stay silent until re-armed
        guard !hasFired.contains(notifKey) else { return }

        hasFired.insert(notifKey)
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

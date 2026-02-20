import SwiftUI

struct ErrorBannerView: View {
    let error: AppError

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(iconColor)

            Text(error.message)
                .font(.system(size: 11))
                .foregroundColor(.primary.opacity(0.9))

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .cornerRadius(6)
    }

    private var icon: String {
        switch error {
        case .keychainNotFound: return "key.slash"
        case .authExpired: return "lock.trianglebadge.exclamationmark"
        case .networkError: return "wifi.exclamationmark"
        case .rateLimited: return "clock.badge.exclamationmark"
        }
    }

    private var iconColor: Color {
        switch error {
        case .keychainNotFound, .authExpired: return .orange
        case .networkError: return .red
        case .rateLimited: return .yellow
        }
    }

    private var backgroundColor: Color {
        iconColor.opacity(0.12)
    }
}

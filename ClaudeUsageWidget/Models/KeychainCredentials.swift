import Foundation

struct KeychainCredentials: Codable {
    let claudeAiOauth: OAuthCredentials

    struct OAuthCredentials: Codable {
        let accessToken: String
        let refreshToken: String
        let expiresAt: Int64
        let subscriptionType: String?
        let rateLimitTier: String?

        var expiresAtDate: Date {
            Date(timeIntervalSince1970: Double(expiresAt) / 1000.0)
        }

        var isExpired: Bool {
            expiresAtDate < Date()
        }

        var isExpiringSoon: Bool {
            expiresAtDate < Date().addingTimeInterval(5 * 60)
        }
    }
}

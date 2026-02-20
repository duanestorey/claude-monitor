import Foundation

struct ProfileResponse: Codable {
    let account: AccountInfo
    let organization: OrganizationInfo
}

struct AccountInfo: Codable {
    let uuid: String
    let fullName: String?
    let displayName: String?
    let email: String

    enum CodingKeys: String, CodingKey {
        case uuid
        case fullName = "full_name"
        case displayName = "display_name"
        case email
    }

    var name: String {
        displayName ?? fullName ?? email
    }
}

struct OrganizationInfo: Codable {
    let uuid: String
    let name: String
    let organizationType: String?
    let rateLimitTier: String?
    let hasExtraUsageEnabled: Bool?
    let subscriptionStatus: String?

    enum CodingKeys: String, CodingKey {
        case uuid, name
        case organizationType = "organization_type"
        case rateLimitTier = "rate_limit_tier"
        case hasExtraUsageEnabled = "has_extra_usage_enabled"
        case subscriptionStatus = "subscription_status"
    }

    var planLabel: String {
        guard let tier = rateLimitTier else { return "Pro" }
        if tier.contains("5x") { return "Max 5x" }
        if tier.contains("20x") { return "Max 20x" }
        if tier.contains("max") { return "Max" }
        return "Pro"
    }
}

import SwiftUI

struct AccountInfoSection: View {
    let profile: ProfileResponse

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Claude Usage")
                    .font(.system(size: 13, weight: .semibold))
            }

            Spacer()

            Text("\(profile.account.name) (\(profile.organization.planLabel))")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

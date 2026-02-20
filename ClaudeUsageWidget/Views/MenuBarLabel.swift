import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        let text = viewModel.menuBarText
        if text.isEmpty {
            Label("Claude", systemImage: "sparkle")
        } else {
            Label {
                Text(text)
            } icon: {
                Image(systemName: "sparkle")
            }
        }
    }
}

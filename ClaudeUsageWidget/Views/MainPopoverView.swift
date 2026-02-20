import SwiftUI

struct MainPopoverView: View {
    @ObservedObject var viewModel: UsageViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Account header
                if let profile = viewModel.profile {
                    AccountInfoSection(profile: profile)
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                } else {
                    HStack {
                        Text("Claude Usage")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }

                // Error banner
                if let error = viewModel.error {
                    ErrorBannerView(error: error)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                }

                // Weekly pace pressure gauge
                if let usage = viewModel.usage {
                    UsagePressureView(usage: usage)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                }

                Divider()
                    .padding(.horizontal, 14)

                // Usage bars
                if let usage = viewModel.usage {
                    UsageBarsSection(usage: usage)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                    Divider()
                        .padding(.horizontal, 14)
                }

                // Daily activity chart
                if let activities = viewModel.stats?.dailyActivity, !activities.isEmpty {
                    DailyActivityChart(activities: activities)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                    Divider()
                        .padding(.horizontal, 14)
                }

                // Model usage
                if let modelUsage = viewModel.stats?.modelUsage, !modelUsage.isEmpty {
                    ModelUsageSection(modelUsage: modelUsage)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                    Divider()
                        .padding(.horizontal, 14)
                }

                // Footer
                footerView
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
        }
        .frame(width: 320)
        .frame(minHeight: 580, maxHeight: 700)
        .task {
            await viewModel.refreshIfStale()
        }
    }

    private var footerView: some View {
        VStack(spacing: 6) {
            // Session/message stats
            if let stats = viewModel.stats {
                let sessions = stats.totalSessions ?? 0
                let messages = stats.totalMessages ?? 0
                HStack {
                    Text("\(sessions) sessions · \(formatNumber(messages)) messages")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                    Spacer()
                }
            }

            HStack(spacing: 8) {
                // Last updated
                if let lastUpdated = viewModel.lastUpdated {
                    Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                }

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }

                Spacer()

                // Refresh button
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                // Settings button
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                // Quit button
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Text("Quit")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
    }

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

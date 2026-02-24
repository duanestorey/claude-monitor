# Claude Usage Widget

A native macOS menu bar app that shows your Claude subscription usage limits in real-time. Mirrors the data from Claude Code's `/usage` command but always visible in your menu bar.

Built for Claude Max subscribers who want to keep an eye on session limits, weekly quotas, extra usage spending, and daily activity — without switching context.

## What It Shows

- **Weekly Pace Gauge** — are you ahead or behind your expected usage rate for the week? Green means you have room to sprint, red means slow down.
- **Session Limit (5h)** — current session utilization with time until reset
- **Weekly Limit (7d)** — all-model and Sonnet-only weekly utilization
- **Extra Usage** — dollar amount spent vs monthly limit
- **Daily Activity Chart** — messages per day over the last 7 days (Swift Charts)
- **Model Usage Breakdown** — output tokens and cache usage per model (Opus, Sonnet, etc.)
- **Session & Message Totals** — cumulative stats from Claude Code

The menu bar icon is a gauge that reflects your most-constrained limit. Optionally display session %, week %, or both as colored text next to the icon — green under 70%, orange 70-90%, red above 90%.

## Notifications

Configurable macOS notifications when usage crosses thresholds:
- Session limit (default: 80%)
- Weekly limit (default: 75%)
- Extra usage (default: 75%)

Each can be toggled independently with a custom threshold.

## Requirements

- macOS 13.0+
- Xcode 15.0+ (with command line tools)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- An active [Claude Code](https://claude.ai/code) session (the app reads your OAuth credentials from the macOS Keychain)

## Build & Install

### Option A: Command Line

```bash
# Clone the repo
git clone https://github.com/duanestorey/claude-monitor.git
cd claude-monitor

# Install XcodeGen if you don't have it
brew install xcodegen

# Generate the Xcode project
xcodegen generate

# Build the release binary
xcodebuild -scheme ClaudeUsageWidget -configuration Release build

# Copy to Applications
cp -R ~/Library/Developer/Xcode/DerivedData/ClaudeUsageWidget-*/Build/Products/Release/ClaudeUsageWidget.app /Applications/

# Launch
open /Applications/ClaudeUsageWidget.app
```

### Option B: Xcode GUI

```bash
# Clone and generate the project
git clone https://github.com/duanestorey/claude-monitor.git
cd claude-monitor
brew install xcodegen
xcodegen generate
```

Then open `ClaudeUsageWidget.xcodeproj` in Xcode, select the **ClaudeUsageWidget** scheme, set the build configuration to **Release**, and hit **Cmd+R** to build and run. To install permanently, use **Product > Archive** or copy the built `.app` from Xcode's DerivedData to `/Applications`.

### First Launch

The app appears as a gauge icon in your menu bar with no Dock icon. Click the gauge to open the usage popover. Click anywhere outside to dismiss.

**Important:** You must have logged into [Claude Code](https://docs.anthropic.com/en/docs/claude-code) at least once before launching this app. The app reads your existing OAuth credentials from the macOS Keychain — it does not handle login itself.

## Settings

Click the gear icon in the popover footer to open settings:

- **Refresh interval** — how often to poll the API (1, 2, 5, 10, or 15 minutes)
- **Menu bar display** — icon only, session %, week %, or both
- **Notification thresholds** — toggle and configure alerts for session, weekly, and extra usage limits
- **Launch at login** — start automatically (requires the app to be in `/Applications`)

## How It Works

The app reads your Claude Code OAuth token from the macOS Keychain (`Claude Code-credentials` entry) and uses it to query two Anthropic API endpoints:

- `GET /api/oauth/usage` — session and weekly utilization percentages, extra usage credits
- `GET /api/oauth/profile` — account name, email, plan type

It also watches `~/.claude/stats-cache.json` for changes — this file is written by Claude Code and contains daily activity stats, model token usage, and session totals.

The app is **not sandboxed** because it needs to read Claude Code's Keychain entry. It only makes outbound HTTPS requests to `api.anthropic.com`. No data is stored or transmitted anywhere else.

## Architecture

Zero third-party dependencies. Pure Swift using SwiftUI, AppKit, Combine, Charts, and Foundation.

| Component | Role |
|-----------|------|
| `AppDelegate` | Owns `NSStatusItem` + `NSPopover`, updates menu bar icon/text reactively |
| `UsageViewModel` | Polls API, manages state, handles errors and backoff |
| `KeychainService` | Reads OAuth token via `/usr/bin/security` CLI |
| `AnthropicAPIClient` | Async URLSession calls with 401 retry and 429 backoff |
| `StatsCacheReader` | Watches stats file with `DispatchSource` |
| `NotificationService` | Fires macOS notifications at configurable thresholds |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `xcodegen: command not found` | Run `brew install xcodegen` |
| Build fails with "no scheme" | Run `xcodegen generate` first — the `.xcodeproj` is not checked into the repo |
| Gauge shows "No Token" | Make sure you've logged into Claude Code at least once (`claude` in your terminal) |
| Gauge shows "Auth Error" | Your OAuth token may have expired — open Claude Code to refresh it, then relaunch the app |
| macOS blocks the app | Go to **System Settings > Privacy & Security** and click **Open Anyway** |
| No Keychain access prompt | The app uses the `security` CLI and does not trigger a Keychain prompt — if it can't read the token, ensure Claude Code's credentials exist in Keychain Access under `Claude Code-credentials` |

## License

MIT

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Generate Xcode project from project.yml (required after adding/removing files)
xcodegen generate

# Build
xcodebuild -scheme ClaudeUsageWidget -configuration Release build

# Copy built app to project root for easy launching
rm -r ClaudeUsageWidget.app 2>/dev/null; cp -R ~/Library/Developer/Xcode/DerivedData/ClaudeUsageWidget-*/Build/Products/Release/ClaudeUsageWidget.app .

# Launch
open ClaudeUsageWidget.app
```

**Important:** After adding or removing any `.swift` file, you must run `xcodegen generate` before building — the xcodeproj is generated from `project.yml`, not managed manually.

## Architecture

**MVVM + Singleton Services, zero third-party dependencies, macOS 13+.**

The app is an `LSUIElement` (no Dock icon). It uses a manually managed `NSStatusItem` + `NSPopover` instead of SwiftUI's `MenuBarExtra` because `MenuBarExtra`'s label closure doesn't re-render reactively — the `AppDelegate` in `ClaudeUsageWidgetApp.swift` owns the status item and updates the button icon/text/color via Combine subscribers.

### Data Flow

```
~/.claude/.credentials.json  or  Keychain ("Claude Code-credentials")  →  KeychainService  →  OAuth token
                                                                                          ↓
Anthropic API (/oauth/usage, /oauth/profile)  →  AnthropicAPIClient  →  UsageViewModel
                                                                          ↓
~/.claude/projects/**/*.jsonl  →  TranscriptStatsReader (FSEvents watch)  →  Views
```

- **KeychainService** reads `~/.claude/.credentials.json` first, then falls back to the Keychain by shelling out to `/usr/bin/security` (avoids sandbox/code-signing issues with Security.framework, and `security -w` truncation of long tokens)
- **TranscriptStatsReader** builds the daily activity chart, model usage, and session/message totals from Claude Code's session transcripts. It watches `~/.claude/projects` with an FSEvents stream, parses on a background queue, and caches per-file results keyed on mtime + size so only changed transcripts are re-read
- **UsageViewModel** polls the API on a timer (default 5min), pauses on sleep, resumes on wake
- **NotificationService** fires macOS notifications when configurable usage thresholds are crossed, tracks sent notifications per reset cycle to avoid spam

### Key Design Decisions

- **Not sandboxed** — needs Keychain access to Claude Code's credential entry
- **Token expiry**: checked before each API call with 5-min buffer; on 401, re-reads Keychain (Claude Code may have refreshed) and retries once
- **Rate limiting**: exponential backoff up to 30 min, respects `Retry-After` header
- **Menu bar updates**: `AppDelegate.updateButton()` sets the `NSStatusBarButton`'s image (gauge needle position) and `attributedTitle` (colored percentage text) — this is the only reliable way to get reactive colored text in the menu bar
- **Settings window**: uses SwiftUI `Window` scene with `@Environment(\.openWindow)` — requires `NSApp.activate(ignoringOtherApps: true)` first for LSUIElement apps

### Local Transcript Stats

- **Do not use `~/.claude/stats-cache.json`** — Claude Code stopped updating it (last write April 2026), which froze the chart and model usage. Transcripts are the source of truth.
- Each transcript line is a JSON event. `type: "assistant"` lines carry `message.id`, `message.model`, `message.usage` (`input_tokens`, `output_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`) and `content` (`tool_use` blocks). One API response is split across several lines sharing `message.id` — **de-duplicate by `message.id`** or tokens get double-counted
- Messages = user prompts (`type: "user"`, excluding `isMeta` and tool-result lines) + unique assistant responses. Model `<synthetic>` is skipped
- Subagent transcripts live in `<project>/<session>/subagents/*.jsonl` and are included (they share the parent `sessionId`)
- Days are bucketed in **local time**; the daily series is zero-filled so the chart always shows the last 7 calendar days
- Claude Code prunes transcripts (`cleanupPeriodDays`, default 30), so totals cover the retained window — the Model Usage header shows "since <date>"
- Model display names are derived from the ID by `ModelNameFormatter` (`claude-opus-5-5` → "Opus 5.5"); don't hardcode version names

### API Details

- Base URL: `https://api.anthropic.com/api/oauth`
- Required headers: `anthropic-beta: oauth-2025-04-20`, `User-Agent: claude-code/2.1.44`
- `/usage` returns `five_hour`, `seven_day`, `seven_day_sonnet`, `extra_usage` — each nullable, with `utilization` (0-100) and `resets_at` (ISO 8601)
- `/profile` returns `account` (name, email) and `organization` (plan type, rate limit tier)
- Extra usage amounts are in **cents** (`monthly_limit: 4250` = $42.50)

### Settings Persistence

All via `UserDefaults` / `@AppStorage`: `refreshInterval`, `menuBarDisplayMode`, `notificationsEnabled`, `notifySessionEnabled`/`At`, `notifyWeekEnabled`/`At`, `notifyExtraEnabled`/`At`.

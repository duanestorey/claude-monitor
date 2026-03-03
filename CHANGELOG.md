# Changelog

## 1.1.0

### New Features
- **App icon** — custom gauge icon replaces the generic blank square
- **Version display** — version number shown in the popover footer

### Bug Fixes
- **Credential reading fallback** — reads `~/.claude/.credentials.json` first, falls back to Keychain; fixes failures on machines where the `security -w` command truncates long OAuth tokens
- **Quit not quitting** — the app now closes all windows (including Settings) before terminating, preventing the process from hanging
- **Settings window position** — opens centered on screen instead of at an unpredictable offset
- **Asset catalog** — added missing root `Contents.json` so the icon compiles correctly into `Assets.car`

### Internal
- Added `CFBundleIconName` for modern macOS Dock icon resolution
- Removed conflicting standalone `.icns` / asset catalog duplication

## 1.0.0

Initial release.

- macOS menu bar widget showing Claude subscription usage
- Session (5h), weekly (7d), and extra usage bars with reset timers
- Weekly pace pressure gauge
- Daily activity chart and model usage breakdown
- Configurable notifications at usage thresholds
- Menu bar display modes: icon only, session %, week %, or both
- Settings window with refresh interval, notifications, and launch-at-login
- OAuth token read from Claude Code Keychain entry
- Local stats from `~/.claude/stats-cache.json` with file watching

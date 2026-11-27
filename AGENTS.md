# AGENTS.md

Repository guidance for coding agents working in `claude-monitor` (app name: Claude Usage Widget).

## Project Summary

- Native macOS menu bar application for AI usage telemetry.
- Current shipping behavior is Claude-focused, but the codebase is small enough to support a clean provider abstraction.
- Single app target, no third-party dependencies, macOS 13+, Swift 5.9, SwiftUI + AppKit + Combine + Charts + Foundation.
- The app is intentionally `LSUIElement` and intentionally **not sandboxed** because it reads local credential stores and usage files.

## Build And Regeneration

```bash
# Regenerate the Xcode project after adding or removing files
xcodegen generate

# Build the app into ./build (gitignored)
xcodebuild -scheme ClaudeUsageWidget -configuration Release -derivedDataPath build build
```

`project.yml` is the source of truth. Do not hand-edit the generated project for durable changes.

- `xcodegen generate` rewrites `ClaudeUsageWidget/Info.plist` from `project.yml`'s `info.properties`. Bundle keys (including `CFBundleShortVersionString: $(MARKETING_VERSION)`) must be declared there, or regeneration silently resets them.
- The version lives only in `MARKETING_VERSION` in `project.yml`; the popover footer reads it from the bundle.
- See `CLAUDE.md` for API details and the Claude Code transcript format.

## Source Map

- `ClaudeUsageWidget/ClaudeUsageWidgetApp.swift`
  App entrypoint plus `AppDelegate`, which owns the `NSStatusItem` and `NSPopover`.
- `ClaudeUsageWidget/ViewModels/UsageViewModel.swift`
  Main orchestration layer for refresh, polling, error state, stats reloads, and settings-backed behavior.
- `ClaudeUsageWidget/Services/AnthropicAPIClient.swift`
  Claude usage/profile HTTP client.
- `ClaudeUsageWidget/Services/KeychainService.swift`
  Reads Claude credentials from `~/.claude/.credentials.json` first, then from Keychain via `/usr/bin/security`.
- `ClaudeUsageWidget/Services/TranscriptStatsReader.swift`
  Aggregates daily activity, model token usage, and totals from Claude Code transcripts in `~/.claude/projects/**/*.jsonl`; watches the directory with FSEvents and caches per-file parses. (`~/.claude/stats-cache.json` is no longer maintained by Claude Code — don't read it.)
- `ClaudeUsageWidget/Services/NotificationService.swift`
  Local notification delivery plus threshold hysteresis.
- `ClaudeUsageWidget/Models/*`
  API DTOs (`UsageResponse`, `ProfileResponse`, `KeychainCredentials`) and `LocalUsageStats` (the aggregated transcript stats, plus `ModelNameFormatter`, which derives display names like "Opus 5.5" from model IDs). These are currently Claude-specific.
- `ClaudeUsageWidget/Views/*`
  Compact popover sections and the menu bar presentation.

## Architectural Invariants

- Keep the menu bar implementation on `NSStatusItem` + `NSPopover`.
  The current app does this for a reason: reactive image/title updates and attributed title coloring are reliable here, while `MenuBarExtra` is not a drop-in replacement.
- Keep UI-facing state on the main actor.
  `UsageViewModel` is `@MainActor`; new orchestration layers should preserve that rule.
- Preserve event-driven local file watching.
  `TranscriptStatsReader` uses an FSEvents stream on `~/.claude/projects` plus a per-file mtime/size cache. Follow that pattern instead of switching to blind polling or full re-parses.
- Treat `/usr/bin/security` usage as a deliberate compatibility choice.
  Do not replace it with Security.framework or a custom keychain layer unless there is a concrete, validated need.
- Preserve the menu bar app launch behavior.
  No Dock icon, no stray settings window on startup, transient popover dismissal must keep working.
- Keep business logic out of views.
  Views should render small presentation models or DTOs, not own parsing, aggregation, or provider branching.
- Local stats are optional.
  The activity chart, model usage, and totals exist only for people who use Claude Code on that Mac (and only for its ~30-day transcript retention window). Some users only use the Claude app or claude.ai, so the UI must hide those sections cleanly when stats are empty. The usage limits come from the API and are shared across all Claude surfaces.
- Don't hardcode model names or versions; derive them from model IDs.

## Testing Expectations

- The repository currently has no test target. If you make behavior changes beyond copy or layout, add an XCTest target and wire it into `project.yml`.
- Prioritize tests for:
  - JSON decoding and schema drift handling
  - reset-time/date formatting
  - notification hysteresis and re-arming
  - provider-specific aggregation and mapping
  - file-watch and cache invalidation behavior where practical
- Prefer fixture-driven tests over ad hoc inline JSON blobs once provider support expands.

## Multi-Provider Extension Guidance

- Do not smear provider conditionals across the UI.
  Introduce provider-neutral domain models and provider adapters first, then migrate Claude onto that abstraction before adding Codex.
- Keep local telemetry and remote billing usage conceptually separate.
  For Claude today they happen to be combined in one screen; for Codex, local session telemetry and organization API usage are different products and should not be conflated.
- Keep provider-specific copy localized.
  Strings like `"Claude Usage"`, `"Session (5h)"`, and `"Week — All Models (7d)"` should move behind presentation helpers once another provider is introduced.
- Make the normalization layer explicit.
  A future provider should produce a normalized snapshot for the UI: identity, limits, activity series, model usage, totals, and provider health/errors.

## Releases

Releases are GitHub releases with a zipped universal `.app` attached (`ClaudeUsageWidget-vX.Y.Z.zip`), so people can install without building.

```bash
# 1. Bump MARKETING_VERSION in project.yml and add a CHANGELOG.md section, then commit and push
xcodegen generate
rm -rf build
xcodebuild -scheme ClaudeUsageWidget -configuration Release -derivedDataPath build \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build

# 2. Zip with ditto (preserves bundle metadata and the signature)
mkdir -p build/release
ditto -c -k --keepParent build/Build/Products/Release/ClaudeUsageWidget.app build/release/ClaudeUsageWidget-vX.Y.Z.zip

# 3. Publish
gh release create vX.Y.Z build/release/ClaudeUsageWidget-vX.Y.Z.zip --target main --title "vX.Y.Z" --notes-file <notes>
```

- Builds are ad-hoc signed and **not notarized**, so recipients must click **Open Anyway** (or remove the quarantine attribute) on first launch. Release notes and the README must say so.
- Notarizing requires a **Developer ID Application** certificate. The maintainer's Apple Development / Apple Distribution certificates can't be used to distribute outside the App Store.
- Releases are public and outward-facing: only create one when the maintainer asks.

## Operational Hygiene

- Avoid reading or logging secrets. If you inspect credential material, prefer structure-only reads and never persist tokens in repo files.
- Don't open signing certificates, `.p12`/`.p8` keys, or `.env` files, in this repo or in sibling projects. Ask the maintainer about signing setup instead.
- If you add or remove Swift files, regenerate the project before considering the work complete.
- Maintain the zero-dependency stance unless a new dependency is strongly justified.

# MyApp — iOS + tvOS (Swift 6, SwiftUI-first)

<!-- composed: not from official docs; validate in your repo. Template from the Claude Code iOS/tvOS playbook. Replace the placeholders listed in INSTALL.md, delete what your repo does not have, and keep this file under 200 lines (official guidance: longer files reduce adherence). This file is context, not enforcement: hard stops live in .claude/settings.json (deny/ask rules) and .claude/hooks/. Block-level HTML comments like this one are stripped before Claude sees the file. -->

## What this is

One codebase, two app targets: `MyApp` (iOS 17+) and `MyApp-tvOS` (tvOS 17+). Real code lives in local Swift
packages under `Sources/` (`MyAppCore`, `MyAppUI`, `MyAppPlatform`, `MyAppFeatures`); `App/` is the
composition root. `MyApp.xcodeproj` is generated from `project.yml` (XcodeGen) — never edit the pbxproj.
Quality gates (SwiftLint strict, SwiftFormat, Swift 6 language mode, architecture tests) run on every edit,
every stop, and in CI. Running a gate is how you learn its value; do not re-derive it.

## Build, test, run — use the wrappers, never raw `xcodebuild`

| Task                      | Command                                                                 |
| ------------------------- | ----------------------------------------------------------------------- |
| Build iOS / tvOS          | `scripts/xcb.sh build ios` · `scripts/xcb.sh build tvos` (or `/build`)   |
| One test class            | `scripts/xcb.sh test ios --only-testing MyAppTests/CartTotalsTests`      |
| One test                  | `scripts/xcb.sh test ios --only-testing MyAppTests/CartTotalsTests/applies…` |
| Package logic only        | `swift test --filter CartTotals` (inside `Sources/MyAppCore`'s package)  |
| Whole suite (before a PR) | `scripts/xcb.sh test ios` and `scripts/xcb.sh test tvos`                 |
| Run on a simulator        | `/run-sim ios <bundle-id>` · `/run-sim tvos <bundle-id>` (uses `scripts/sim.sh`) |
| Failing-test details      | `scripts/xcresult-failures.sh build/xcresults/<bundle>.xcresult`         |
| Lint / format one file    | happens automatically on edit (hook); `swiftlint lint --strict <file>`   |
| Import boundaries         | `scripts/arch-check.sh`                                                  |
| Schemes / destinations    | `scripts/xcb.sh list` · `scripts/xcb.sh destinations ios`                |

Wrapper defaults (override with env vars): `SCHEME_IOS=MyApp`, `SCHEME_TVOS=MyApp-tvOS`, `WORKSPACE`/`PROJECT`
auto-detected, `SIM_IOS_NAME="iPhone 16"`, `SIM_TVOS_NAME="Apple TV 4K (3rd generation)"`,
`DERIVED_DATA=./.derivedData`. Output is filtered through xcbeautify; the raw log path is printed on failure.
IMPORTANT: prefer running single tests, not the whole suite, for performance; build at checkpoints, not after
every edit (the Stop hook builds once before you finish).

## Narrowest check that can fail

| What you changed                              | Run this before saying "done"                                      |
| --------------------------------------------- | ------------------------------------------------------------------ |
| Core logic (`Sources/MyAppCore`)              | `swift test --filter <Suite>` then `scripts/xcb.sh build ios`      |
| A view or view model                          | `scripts/xcb.sh build ios` + `build tvos`, then `/run-sim` + screenshot |
| tvOS-only code or anything with focus         | `scripts/xcb.sh build tvos`, `/run-sim tvos`, move focus, screenshot |
| A test                                        | `scripts/xcb.sh test <platform> --only-testing <Target/Class/test>` |
| Imports, `Package.swift`, `project.yml`       | `scripts/arch-check.sh`, then the `architecture-guardian` subagent |
| Persistence (`Sources/MyAppPlatform/Persistence`) | the persistence test class + migration test; then ask (see below) |
| Localization / strings                        | build both platforms; check `Localizable.xcstrings` compiles       |
| Anything before a PR                          | `/review-pr`, then `scripts/xcb.sh test ios` and `test tvos`       |

Show evidence, not claims: paste the last lines of the command and its exit status.

## Architecture (full table: `.claude/rules/architecture.md`)

Dependency direction is one-way: `MyAppCore` <- `MyAppUI`, `MyAppCore` <- `MyAppPlatform`, both <- `MyAppFeatures` <- `App`.
`MyAppUI` and `MyAppPlatform` are siblings and never import each other. Core imports only Foundation and
Observation; UI, persistence and OS frameworks live in Platform behind Core-declared protocols (ports). Each
boundary is enforced three times (SwiftLint custom rule, `Tests/ArchitectureBoundaryTests.swift`,
`scripts/arch-check.sh`); disabling one leaves the others red. A new module or edge is a human decision.

## Swift 6 strict concurrency (details: `.claude/rules/swift.md`)

- Data-race diagnostics are build failures; fix isolation, never silence it.
- UI state is `@MainActor`; cross-actor Core types are `Sendable` value types; `@unchecked Sendable` and
  `nonisolated(unsafe)` need a same-line proof comment (lint fails otherwise).
- `.task {}` not `Task {}` in `onAppear`; `[weak self]` in anything that outlives its owner.
- No `try!`, `as!`, force unwraps, or `print` in app code; `os.Logger` with privacy annotations.

## SwiftUI first, UIKit when

- SwiftUI + `@Observable` + `NavigationStack` for every new screen on both platforms.
- UIKit only for: `UICollectionView` with custom focus/parallax behaviour on tvOS, `TVUIKit` lockups, a
  system API without a SwiftUI equivalent, or a measured performance problem — wrapped once in a
  `UIViewRepresentable`/`UIViewControllerRepresentable` inside `MyAppUI`, never scattered.
- Split view bodies before the type checker times out (`.claude/rules/swiftui.md`).

## tvOS (details: `.claude/rules/tvos.md`)

- Everything interactive must be reachable with the Siri Remote: `focusSection()`, `focusable(interactions:)`,
  `@FocusState`, `UIFocusGuide`; no hover/tap-only affordances; `.disabled()` removes a view from focus.
- Shared files compile for both platforms: `#if os(tvOS)` / `#if os(iOS)` for platform-only API.
- Verify focus with screenshots and, for bugs, `/tvos-focus-debug` (focus logging + `UIFocusDebugger`).

## Needs human sign-off — stop and ask, do not work around

- Any change to `*.pbxproj`, `*.xcworkspacedata`, `*.entitlements`, signing, provisioning, capabilities
  (hooks block these file edits); `Info.plist` privacy strings, bundle ids and deployment targets are
  editable but need approval and a justification in the PR.
- Adding, removing or bumping a dependency (`Package.swift`, `Package.resolved`, `Podfile`, `Podfile.lock`);
  lockfiles are regenerated by the tool, never edited.
- SwiftData/CoreData model or migration changes (`@Model`, `VersionedSchema`, `SchemaMigrationPlan`).
- Weakening any gate: `// swiftlint:disable`, lint/format config, coverage floors, deleting or disabling a
  test, lowering strict concurrency, editing `scripts/arch-check.sh` rules or the boundary test.
- Version/build bumps, tags, TestFlight/App Store uploads, `fastlane`, `git push` (ask rules), force push (denied).
- Re-spelling a denied command (`/bin/rm`, `bash -c`, `git -C . push`) is forbidden. Stop and ask.
- Reading secrets: `.env*`, `*.p12`, `*.p8`, `*.mobileprovision`, `GoogleService-Info.plist` (denied).

## Session hygiene

- One task per session, named after the task: `claude -n fix-crash-1234 -w fix-crash-1234` (worktree =
  cold DerivedData; add `.derivedData/`, `build/`, `.claude/worktrees/` to `.gitignore`, and local config to
  `.worktreeinclude`).
- Explore -> plan -> implement -> verify. Start non-trivial work in plan mode (`Shift+Tab` or `/plan …`); if
  the diff fits in one sentence, skip the plan.
- `/compact` at each green-build milestone with instructions, for example
  `/compact Focus on the files changed, the exact xcb.sh/test commands used, and open TODOs`.
  When compacting, always preserve the full list of modified files and any test commands.
- `/clear` once the PR is open, or after correcting the same mistake twice (the context is polluted; restart
  with a more specific prompt). Use `/btw` for side questions.
- Checkpoints (`Esc Esc` / `/rewind`) do not capture Bash-driven changes (`xcodegen generate`, `pod install`);
  commit at milestones instead.
- Never paste raw `xcodebuild` logs into the conversation; use the wrappers' filtered output and
  `scripts/xcresult-failures.sh`.

## Where things are

- Path-scoped rules (load when you touch matching files): `.claude/rules/{swift,swiftui,architecture,testing,tvos,xcode-project}.md`
- Skills: `/build`, `/test`, `/run-sim`, `/triage-crash`, `/tvos-focus-debug`, `/review-pr`, `/release-check` (human-triggered)
- Subagents: `swift-reviewer`, `swift-test-writer`, `architecture-guardian` (read-only), `tvos-focus-debugger`
- Hooks (`.claude/settings.json`): protect-files + guard-bash (PreToolUse), format-swift (PostToolUse),
  session-start (SessionStart), stop-gate (Stop; builds before you can finish; 8-continuation cap)
- MCP (`.mcp.json`): `MobileBuildMCP` (headless build/sim/UI automation), `xcode` (Xcode 26.3+ `xcrun mcpbridge`; needs Xcode open)
- Review guidelines for the managed Code Review service and `/review-pr`: `REVIEW.md`
- Deeper docs: add an import such as `@docs/ARCHITECTURE.md` (without the backticks) only when that file exists;
  imports load at launch and cost context every session.

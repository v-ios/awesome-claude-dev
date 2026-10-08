# Review instructions

<!-- Shape per the REVIEW.md example in the Claude Code code-review docs (research/notes/governance_and_context_engineering.md KQ9). Consumers: Anthropic's managed Code Review service (Team/Enterprise GitHub app), the local `/review-pr` skill and `scripts/claude-review.sh`, which inject this file. Note: the bundled `/code-review` command follows CLAUDE.md but does NOT read REVIEW.md. Content is composed for Swift/tvOS; validate in your repo. -->

## What Important means here

Reserve **Important** for findings that would ship a real defect:

- A data race or isolation bug: non-`Sendable` state crossing actors, `@unchecked Sendable` or
  `nonisolated(unsafe)` without a proof comment, UI state mutated off the main actor, a continuation resumed
  twice or never.
- A retain cycle or leak: strong `self` in a long-lived closure, Combine sink or timer; a strong delegate; an
  observer that is never removed; `Task {}` in `onAppear` instead of `.task`.
- Main-thread stalls: synchronous I/O, image decoding, JSON parsing or large sorts inside a SwiftUI `body` or
  on the main actor.
- A tvOS screen or control that the focus engine cannot reach: missing `focusSection()`/`UIFocusGuide`,
  `.disabled()` on a tvOS control, hover- or tap-only affordances, `pressesBegan` without `super`.
- Shared code that does not compile for one platform (`#if os(...)` missing).
- A layering violation: `MyAppCore` importing UI/persistence/OS frameworks, `MyAppUI` <-> `MyAppPlatform`
  imports, `MyAppFeatures` importing `MyAppPlatform` directly, business logic in a view.
- `try!`, `as!`, force unwraps or `fatalError` on a reachable path in app code.
- Any change to `.pbxproj`, `Podfile.lock`, `Package.resolved`, `*.entitlements`, signing, or `Info.plist`
  privacy keys that the PR description does not explicitly justify.
- A weakened gate: `// swiftlint:disable`, a disabled or deleted test, an assertion loosened to pass, lint or
  coverage config relaxed, strict concurrency lowered.
- Missing Swift Testing coverage for new Core logic (happy path and error path), or XCTest and Swift Testing
  mixed in one target.

## Cap the nits

Report at most five Nits per review. Prefer nits about naming that misleads, missing accessibility labels on
custom controls, hard-coded user-facing strings, and `#Preview`s missing for new views.

## Do not report

- Formatting, import order, line length, or anything `.swiftlint.yml`, `.swiftformat`,
  `scripts/arch-check.sh` and `Tests/ArchitectureBoundaryTests.swift` already enforce in CI.
- `Package.resolved` / `Podfile.lock` churn that belongs to an approved dependency bump named in the PR.
- Generated files (`*.generated.swift`, `Generated/`, `Derived/`, XcodeGen/Tuist output).
- Pre-existing issues outside the diff (mention once as Pre-existing if they block the change).
- Style preferences between equivalent SwiftUI modifiers or UIKit patterns.

## Always check

- New Core logic has Swift Testing tests for both the happy and the error path, written against fakes.
- `os.Logger` is used instead of `print`, with `privacy: .private` on user-derived values.
- Shared views compile for iOS and tvOS, and new tvOS-reachable controls have a focus path and, when the PR
  fixes a focus bug, an `XCUIRemote` UI test.
- New user-facing strings go through the string catalog; custom controls have accessibility labels; layouts
  survive the largest Dynamic Type size.
- `.task {}` is used for view-scoped async work; `[weak self]` where a closure outlives its owner.
- The PR description says which `scripts/xcb.sh` / test commands were run and shows their result.

## Verification bar

Before posting an Important finding, confirm it against the actual code paths (read the callers, the actor
isolation of the enclosing type, and whether the view is tvOS-compiled). A finding you cannot confirm is a Nit
with a question, not an Important.

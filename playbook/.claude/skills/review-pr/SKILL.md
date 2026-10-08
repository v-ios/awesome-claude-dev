---
name: review-pr
description: Swift/SwiftUI/tvOS-specific review of the current branch's diff (concurrency and Sendable, @MainActor, retain cycles, SwiftUI performance, tvOS focus, accessibility, localization, architecture boundaries) with severity-tagged findings. Use before opening a PR or when asked to review a branch.
argument-hint: "[base-ref, default main]"
allowed-tools: Bash(git diff *), Bash(git log *), Read, Grep, Glob
---

<!-- composed: not from official docs; the `!` injection form is verbatim from the skills docs (summarize-changes example) quoted in research/notes/governance_and_context_engineering.md KQ5; the focus areas come from the composed swift-reviewer in KQ6 and REVIEW.md. If your default branch is not `main`, pass the base ref or edit the three lines below. -->

## Commits on this branch

!`git log --oneline main..HEAD 2>/dev/null | head -n 30 || true`

## Diff stat

!`git diff --stat main...HEAD 2>/dev/null || true`

## Swift diff (first 2000 lines; use Read/Grep for the rest)

!`git diff main...HEAD -- '*.swift' 2>/dev/null | head -n 2000 || true`

## Repository review guidelines (REVIEW.md)

!`cat REVIEW.md 2>/dev/null || echo "(no REVIEW.md)"`

## Instructions

Base ref: `$ARGUMENTS` (if given and not `main`, rerun `git diff <base>...HEAD -- '*.swift'` yourself first).
Review ONLY the diff; read surrounding code to confirm a finding, not to review untouched files. Check, in order:

1. **Concurrency** — non-`Sendable` values crossing isolation; `@unchecked Sendable` / `nonisolated(unsafe)` without a proof comment; UI state mutated off `@MainActor`; `Task {}` in `onAppear`; continuations resumed twice or never; detached tasks without cancellation.
2. **Memory** — strong `self` in long-lived closures/Combine sinks; strong delegates; observers never removed; `unowned` where the lifetime is not provable; caches without bounds.
3. **SwiftUI performance/correctness** — heavy work in `body`; `AnyView`; identity churn (`id:` on unstable values); `@State` holding reference types that should be `@Observable`; `NavigationView`; image decoding on the main thread.
4. **tvOS focus** — new interactive views unreachable by the focus engine; missing `focusSection()`/`UIFocusGuide`; `.disabled()` on tvOS; hover/tap-only affordances; `pressesBegan` without `super`; shared view code not compiled for tvOS.
5. **Accessibility** — custom controls without labels/traits; images without labels or `accessibilityHidden`; layouts that break at accessibility Dynamic Type sizes; color-only state.
6. **Localization** — hard-coded user-facing strings; string interpolation that cannot be localized; number/date formatting without `Locale`.
7. **Architecture** — forbidden imports (see `.claude/rules/architecture.md`); business logic in views; new singletons/dependencies; edits to `.pbxproj`, lockfiles, entitlements, Info.plist keys.
8. **Tests** — new logic without Swift Testing coverage; XCTest/Swift Testing mixed in a target; weakened or disabled assertions; `sleep`.

Do not report formatting or anything SwiftLint/SwiftFormat/`scripts/arch-check.sh` already enforce.

## Output format

```
Verdict: APPROVE | REQUEST CHANGES
[BLOCKING]  path/File.swift:123 — <defect in one sentence>. Fix: <concrete change>.
[IMPORTANT] path/File.swift:45  — ...
[NIT]       path/File.swift:9   — ... (max five nits)
Not reviewed: <files skipped and why>
```
BLOCKING = crash, data race/corruption, unreachable tvOS screen, boundary violation, signing/project-file edit.
IMPORTANT = real defect, shippable with a follow-up. NIT = minor. Cite the diff line. No style commentary.

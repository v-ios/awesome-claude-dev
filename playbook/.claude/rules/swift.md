---
paths:
  - "**/*.swift"
---

# Swift rules (load whenever a .swift file is read, written or edited)

<!-- composed: not from official docs; wording adapted from tomada1114/ios-template .claude/rules/swift.md and the practitioner failure modes in the research notes. Validate in your repo. -->

## Concurrency (Swift 6 language mode is on)

- Data-race safety errors are build failures, not warnings to silence. Fix the ownership; never downgrade `SWIFT_STRICT_CONCURRENCY`.
- UI-facing state is `@MainActor` (view models, anything SwiftUI or UIKit reads). Core types that cross actors are `Sendable` value types.
- No `@unchecked Sendable` and no `nonisolated(unsafe)` without a same-line comment proving the invariant (SwiftLint `no_unchecked_sendable_without_proof` / `no_nonisolated_unsafe_without_proof` fail otherwise).
- `Task {}` inside `onAppear` leaks when the view disappears; use `.task {}` (cancels automatically). In UIKit, store the `Task` and cancel in `deinit`/`viewWillDisappear`.
- Capture `[weak self]` in any closure or `Task` that can outlive its owner; `unowned` only when the lifetime is provably shorter (SwiftLint `unowned_variable_capture`).
- Prefer `async/await` and structured concurrency over completion handlers, Combine, or GCD. Bridge legacy callbacks with `withCheckedThrowingContinuation` and resume exactly once.
- Reach for modern APIs: `@Observable` over `ObservableObject`, `NavigationStack` over `NavigationView`, `URLSession` async APIs, Swift Testing. Do not fall back to Objective-C-era patterns when a Swift one exists.

## Error handling

- NEVER `try!`, `as!`, or force-unwrap (`!`) in app code (SwiftLint `force_unwrapping`, `force_try`, `force_cast`). Use `guard let`/`if let`, `try?` with a logged fallback, or throw.
- Throw typed, domain-specific errors from Core; map them to user-facing messages at the UI edge, not at the throw site.
- Never swallow errors silently (`catch {}` without logging or rethrowing).

## Logging

- `os.Logger` is the only logging facility. NEVER `print`, `debugPrint` or `NSLog` in shipped code (SwiftLint `no_print_in_sources`). Annotate user-derived values with `privacy: .private`.

## Design

- Value types first (`struct`/`enum`); `class` only for identity or reference semantics.
- One logical concern per file; SwiftLint's limits (file 400 lines, function body 50, 5 parameters) fail the hook — split long before that.
- Two platforms compile every shared file: iOS-only API goes inside `#if os(iOS)`, tvOS-only inside `#if os(tvOS)`; never `#if !os(iOS)` as a proxy for tvOS.
- `@available`/`if #available` only when the deployment target genuinely requires it; otherwise use the API directly.
- No new third-party dependencies, singletons (`static let shared`), or global mutable state without asking (CLAUDE.md > Needs human sign-off).

## When the compiler or linter pushes back

- Fix the root cause. Do not add `// swiftlint:disable`, `@unchecked Sendable`, `try!`, or `-suppress-warnings` to make a gate pass; those need human sign-off.
- If a SwiftUI expression hits "the compiler is unable to type-check this expression in reasonable time", split the view body (see swiftui.md) instead of adding type annotations everywhere.

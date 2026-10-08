---
paths:
  - "**/*View.swift"
  - "**/*Views/**/*.swift"
  - "**/*Screen.swift"
  - "**/*Screens/**/*.swift"
  - "**/*Modifier.swift"
  - "**/*Style.swift"
---

# SwiftUI rules (load when a view file is touched)

<!-- composed: not from official docs; derived from practitioner findings (type-checker timeouts, @Observable, previews) and Apple focus API docs quoted in the research notes. Validate in your repo. -->

## Body splitting (type-checker timeouts are a known agent failure mode)

- Keep `body` to one container with a handful of children. Anything more than ~30 lines or a nested ternary chain goes into a private computed property (`private var header: some View`) or a child `View` struct.
- Extract a child view when a block has its own state, is reused, or mixes conditions with modifiers.
- Prefer `@ViewBuilder` helpers over `AnyView`; use `Group` for conditional branches.
- When the compiler reports "unable to type-check this expression in reasonable time", split the expression first; add explicit types only if splitting is not enough.

## State and data flow

- `@Observable` models with `@State` ownership at the top of a flow and `@Bindable` where two-way binding is needed. Do not add new `ObservableObject`/`@Published`/`@StateObject` code.
- Views hold no business logic: formatting, validation and orchestration live in the view model or Core. A view maps state to layout and forwards intents.
- Async work starts in `.task { }` (cancels on disappear), never `Task { }` in `onAppear`.
- No image decoding, JSON parsing, or sorting of large collections inside `body`; precompute in the model.
- `NavigationStack` (or `NavigationSplitView`); never `NavigationView`.

## Previews

- Every new view ships a `#Preview` (macro form) with representative sample data from a `PreviewData` fixture; previews must not hit the network or the real persistence store.
- Add a second preview for the "empty" or "error" state when one exists, and a dark-mode / large Dynamic Type variant for screens.

## Focus and input (shared iOS + tvOS code)

- Interactive views must be reachable without touch: use `Button`, `focusable(_:interactions:)` (tvOS 17+), `@FocusState` + `focused(_:equals:)`, and `focusSection()` on containers that hold focusable descendants (tvOS 15+). See tvos.md for the full focus rules.
- Never rely on `onHover`, `onTapGesture`, or drag gestures as the only way to trigger an action; keep a focusable control.
- `.disabled(true)` removes a view from the tvOS focus engine; on tvOS prefer a focusable control that ignores the action, or gate `.disabled` with `#if os(iOS)`.

## Accessibility and localization

- Custom controls get `accessibilityLabel`, and `accessibilityValue` when stateful; images that convey meaning get a label, decorative ones `.accessibilityHidden(true)`.
- User-facing strings are `String(localized:)` / string-catalog keys, never literals; use `Text` with `LocalizedStringKey`.
- Layouts must survive the largest accessibility Dynamic Type size (test with `scripts/sim.sh` + `xcrun simctl ui <udid> content_size` or the preview variant).

## Verification

- After editing a view: `/build ios` and `/build tvos` (shared files must compile for both), then `/run-sim ios <bundle-id>` or `/run-sim tvos <bundle-id>` and read the screenshot before claiming the UI is right.

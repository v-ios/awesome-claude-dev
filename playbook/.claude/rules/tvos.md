---
paths:
  - "**/tvOS/**/*.swift"
  - "**/*TV/**/*.swift"
  - "**/*+tvOS.swift"
  - "**/*TV*.swift"
  - "**/TopShelf*/**/*.swift"
---

# tvOS rules: focus engine, Siri Remote, verification

<!-- composed: not from official docs; focus API facts are from Apple's UIFocus/SwiftUI pages and the practitioner tvOS notes quoted in research/notes/apple_platform_tooling.md §5. Validate in your repo. -->

## Focus engine (the only way a user reaches anything)

- Every interactive element must be focusable and reachable by moving focus with the remote: the focus engine, not your code, decides what gets focus. There is no API to "set focus to X" directly; you influence it with `preferredFocusEnvironments`, `UIFocusGuide`, `focusSection()`, `prefersDefaultFocus(_:in:)`, `@FocusState`.
- SwiftUI: wrap each group of focusable controls that sits beside another group in `.focusSection()` so horizontal/vertical moves cross the gap. `focusSection()` does nothing on a view with no focusable descendants.
- SwiftUI: custom interactive views use `.focusable(interactions: .activate)` (tvOS 17+) plus `onMoveCommand`/`onPlayPauseCommand` or a `Button`; never a bare `onTapGesture`.
- UIKit: fill dead zones with `UIFocusGuide` (`preferredFocusEnvironments` ordered by priority); set the root view controller's `preferredFocusEnvironments` for the initial focus; custom views override `canBecomeFocused` and `didUpdateFocus(in:with:)` and call `setNeedsFocusUpdate()`/`updateFocusIfNeeded()` after layout changes.
- Custom `pressesBegan/pressesEnded` overrides MUST call `super` or focus stops moving (reported with Xcode 27 Device Hub keyboard input).
- `.disabled()` / `isUserInteractionEnabled = false` removes the item from the focus engine; keep a focusable control that ignores the action instead (SwiftLint `no_disabled_modifier_in_tvos_views` warns).
- No hover-only or pointer-only affordances; no touch gestures as the sole trigger. Siri Remote input is: move (swipe/arrows), select, menu/back, play-pause, home. Long-press and swipe gestures cannot be driven by `XCUIRemote`, so give them a button-equivalent.
- Lists: `UICollectionView` cells and SwiftUI `List`/`LazyVGrid` rows must be focusable; use `TVUIKit` (`TVLockupView`, `TVCardView`, `TVPosterView`) for poster/card content that needs parallax and press feedback.
- Parallax / motion: focused poster images use layered images (`UIImageView.adjustsImageWhenAncestorFocused = true` or TVUIKit); custom focusable views animate scale on focus inside `didUpdateFocus(in:with:)` using the coordinator (`addCoordinatedAnimations`).
- Platform split: tvOS-only API goes inside `#if os(tvOS)`; shared files must compile for both platforms (`/build tvos` after every change to shared UI).
- Top Shelf: the extension's principal class adopts `TVTopShelfContentProvider` and returns carousel/sectioned items; call `TVTopShelfContentProvider.topShelfContentDidChange()` to refresh.

## Verification steps (do these, do not assert)

1. `scripts/xcb.sh build tvos` passes.
2. `scripts/sim.sh --device tvos boot && scripts/sim.sh --device tvos install <App.app> && scripts/sim.sh --device tvos launch <bundle-id> -UIFocusLoggingEnabled YES` then `scripts/sim.sh --device tvos screenshot` and read the PNG: the intended item shows the focused appearance.
3. Move focus with the keyboard in Device Hub (arrows, Return, Escape) or `idb ui remote right|select|menu` / MobileBuildMCP `key_press`, screenshot again, confirm the new focus.
4. For a focus bug: `/tvos-focus-debug` (focus logging, `UIFocusDebugger.status()` / `checkFocusability(for:)` / `simulateFocusUpdateRequest(from:)` through lldb batch mode).
5. Add an XCUITest on the tvOS scheme using `XCUIRemote.shared.press(.right)` and `XCTAssertTrue(element.hasFocus)` for any navigation path you fixed.

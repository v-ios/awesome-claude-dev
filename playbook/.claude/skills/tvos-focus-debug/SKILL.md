---
name: tvos-focus-debug
description: Debug a tvOS focus problem (item unreachable, focus stuck, wrong initial focus, dead zone) step by step with focus logging, UIFocusDebugger via lldb batch mode, keyboard/Device Hub input, XCUIRemote tests and screenshot verification. Use for any "can't reach / can't select / focus jumps" report on Apple TV.
argument-hint: "<bundle-id> [AppProcessName] [symptom or view name]"
allowed-tools: Bash(scripts/xcb.sh *), Bash(scripts/sim.sh *), Bash(xcrun simctl *), Bash(xcrun lldb *), Read, Grep, Glob
---

<!-- composed: not from official docs; Apple's focus-debugging facts (UIFocusLoggingEnabled, UIFocusDebugger methods, XCUIRemote, Device Hub keys) are quoted in research/notes/apple_platform_tooling.md §5. The lldb batch probe is the notes' inference, not an Apple-documented recipe. -->

## Steps

Arguments: `$ARGUMENTS` — bundle id, the app's process name (defaults to the scheme), and the symptom.

1. Reproduce on the simulator with focus logging on:
   `scripts/xcb.sh build tvos`, then `scripts/sim.sh --device tvos boot`,
   `scripts/sim.sh --device tvos install <App.app>`,
   `scripts/sim.sh --device tvos launch <bundle-id> -- -UIFocusLoggingEnabled YES`
   (Apple's documented switch; in Xcode it goes under Scheme > Arguments Passed On Launch). Capture the engine's
   log with `scripts/sim.sh --device tvos log 'process == "<AppProcessName>"' --last 2m` while you move focus.
2. Move focus the way a user would: Device Hub keyboard (Left/Right/Up/Down arrows, Return = select, Escape =
   menu/back), or `idb ui remote right|select|menu`, or MobileBuildMCP `key_press` (HID 79 right, 80 left, 81
   down, 82 up, 40 Return, 41 Escape). Screenshot after each move: `scripts/sim.sh --device tvos screenshot` and
   `Read` it. Xcode 27 simulators accept keyboard input only for tvOS 18.0+ runtimes.
3. Ask the focus engine (batch lldb; adjust the process name):
   ```
   xcrun lldb --batch -o "process attach --name <AppProcessName>" \
     -o "expr -l Swift -- import UIKit" \
     -o "po UIFocusDebugger.status()" \
     -o "process detach"
   ```
   Other documented calls (run the same way, or in an Xcode debug session):
   `po UIFocusDebugger.checkFocusability(for: <item>)` (prints "ISSUE: ..." lines such as "This item is not visible onscreen"),
   `po UIFocusDebugger.simulateFocusUpdateRequest(from: <environment>)` (steps through the next-focus decision),
   `po UIFocusDebugger.focusGroups(for: <environment>)`, `po UIFocusDebugger.preferredFocusEnvironments(for: <environment>)`,
   `po UIFocusDebugger.help()`.
   A DEBUG-only in-app menu that logs `UIFocusDebugger.status()` through `os.Logger` is an acceptable stand-in
   when lldb cannot attach; Apple documents the class for lldb use, so keep it behind `#if DEBUG` and never ship it.
4. Correlate with code: `Grep` for `focusSection`, `focusable`, `@FocusState`, `prefersDefaultFocus`,
   `preferredFocusEnvironments`, `UIFocusGuide`, `canBecomeFocused`, `didUpdateFocus`, `pressesBegan`, `.disabled(`
   in the views involved. Check the checklist below.
5. Fix in the view (not by forcing focus from a timer), rebuild, repeat steps 1-2 until the screenshot shows the
   expected focused item after the expected moves.
6. Lock it in with a UI test on the tvOS scheme: `XCUIRemote.shared.press(.right)` / `.select` / `.menu` /
   `.playPause`, then `XCTAssertTrue(app.buttons["Play"].hasFocus)`. Swipes cannot be simulated through
   `XCUIRemote`; give swipe-only paths a button equivalent. (Xcode 27 adds `XCUIVoiceOverService` for VoiceOver focus.)
7. Report: symptom, what `status()`/`checkFocusability` said, root cause, fix, screenshot before/after, the new test.

## Checklist of common causes

- Item not visible or zero-sized (`ISSUE: This item is not visible onscreen`): frame/constraints, `isHidden`, `alpha == 0`, outside the scroll view's visible rect, in a second `UIWindow` without layout.
- `.disabled(true)` / `isUserInteractionEnabled = false` / `canBecomeFocused == false` / `focusable(false)`.
- SwiftUI container next to another group without `.focusSection()`; custom view `focusable()` without `interactions: .activate`.
- UIKit dead zone: missing `UIFocusGuide`, guide `isEnabled == false`, or `preferredFocusEnvironments` empty/stale after layout; forgot `setNeedsFocusUpdate()` + `updateFocusIfNeeded()` after showing/hiding views.
- Wrong initial focus: root view controller's `preferredFocusEnvironments` / `prefersDefaultFocus(_:in:)` points elsewhere; `restoresFocusAfterTransition`.
- `pressesBegan/pressesEnded` override without `super` (focus freezes with keyboard input).
- An overlay/transparent view sits above the items and is itself focusable or swallows presses.
- Collection/table cell not focusable (`shouldUpdateFocusIn`, `canFocusItemAt` returning false; `remembersLastFocusedIndexPath`).
- Focus movement fails silently: subscribe to `UIFocusSystem.movementDidFailNotification` and log `focusHeading` during debugging.
- Hover/pointer-only affordances (`onHover`, `onContinuousHover`) with no focusable control.

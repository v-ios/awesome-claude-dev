---
name: run-sim
description: Build, install and launch the app on an iPhone or Apple TV simulator, capture a screenshot and read it to verify the UI. Use when a change must be seen running, not just compiled.
argument-hint: "[ios|tvos] <bundle-id> [path/to/App.app] [-- launch args]"
allowed-tools: Bash(scripts/xcb.sh *), Bash(scripts/sim.sh *), Bash(xcrun simctl *), Bash(find *), Read
---

<!-- composed: not from official docs; simctl forms are from research/notes/apple_platform_tooling.md §2 (MobileBuildMCP source, ios-simulator-mcp). -->

## Available simulators

!`xcrun simctl list devices available 2>/dev/null | grep -E "iPhone|Apple TV" | head -n 12 || echo "simctl unavailable on this host"`

## Steps

Arguments: `$ARGUMENTS` — platform (`ios` default, or `tvos`), the app's bundle id, optionally the `.app` path and
launch arguments after `--` (for example `-UIFocusLoggingEnabled YES` on tvOS).

1. Build: `scripts/xcb.sh build <platform>` (skip only if `.claude/last-build.json` is a success newer than your edits).
2. Locate the product if no path was given:
   `find .derivedData/Build/Products -maxdepth 2 -name '*.app' -path '*-iphonesimulator/*'` (iOS) or
   `... -path '*-appletvsimulator/*'` (tvOS). Pick the one matching the scheme.
3. Boot: `scripts/sim.sh --device <platform> boot` (uses `SIM_IOS_NAME` / `SIM_TVOS_NAME`, waits for `bootstatus -b`).
4. Install + launch:
   `scripts/sim.sh --device <platform> install <App.app>` then
   `scripts/sim.sh --device <platform> launch <bundle-id> [--console] [--env KEY=VALUE] [-- args]`.
   `--console` streams the app's stdout (`--console-pty`); `os.Logger` output needs
   `scripts/sim.sh --device <platform> log 'subsystem == "<bundle-id>"'` in a second command.
5. Wait for the first screen, then `scripts/sim.sh --device <platform> screenshot` and `Read` the printed PNG path.
   Describe what you see against what the task asked for; list differences; fix; repeat.
6. Drive the UI when needed: `scripts/sim.sh openurl <deep-link>`, `push <bundle-id> payload.json`,
   `privacy grant photos <bundle-id>`, `status_bar override --time "9:41"`, `appearance dark`.
   On Apple TV focus moves with the keyboard in Device Hub (arrows, Return, Escape); scripted input needs
   `idb ui remote up|down|left|right|select|menu` or MobileBuildMCP `key_press` (HID 82/81/80/79, 40, 41).
7. Clean up only if asked: `scripts/sim.sh --device <platform> terminate <bundle-id>`.

## Alternatives (same loop, fewer raw commands)

- MobileBuildMCP (`.mcp.json`, workflows `simulator` + `ui-automation`): `session_set_defaults` once, then
  `build_run_sim`, `screenshot`, `snapshot_ui` (accessibility tree with element refs), `key_press`, `tap`,
  `record_sim_video`. Run `session_show_defaults` before the first build in a session.
- Xcode 26.3+ MCP (`xcrun mcpbridge`, server `xcode` in `.mcp.json`): needs Xcode open on the project; gives
  Preview rendering and, on Xcode 27, simulator boot/launch/screenshot and Siri Remote navigation tools.

## Report

Bundle id, simulator name/udid, the screenshot path(s), and a one-paragraph comparison of the screenshot with the
expected result. Show evidence, do not assert.

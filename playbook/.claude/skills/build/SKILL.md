---
name: build
description: Build the app for the iOS or tvOS simulator through scripts/xcb.sh and report only the errors. Use after any Swift change, before running the app, and before claiming a task is done.
argument-hint: "[ios|tvos|both] [--scheme S] [--configuration C]"
allowed-tools: Bash(scripts/xcb.sh *), Read
---

<!-- composed: not from official docs; the frontmatter fields and $ARGUMENTS come from the skills docs quoted in research/notes/governance_and_context_engineering.md KQ5. -->

## Last recorded build

!`cat .claude/last-build.json 2>/dev/null || echo "no previous xcb.sh run"`

## Steps

Arguments: `$ARGUMENTS` (default platform: `ios`; `both` builds iOS then tvOS).

1. Run `scripts/xcb.sh build <platform> [flags]`, where `<platform>` is the first word of the arguments
   (`ios` when omitted) and `[flags]` are any remaining `--scheme`/`--configuration` arguments passed through
   unchanged. For `both`, run iOS first, then tvOS, even if iOS fails (shared files must compile for both). Do not call `xcodebuild` directly; the wrapper sets the
   destination, `-derivedDataPath`, a timestamped `-resultBundlePath`, `-quiet`, `-skipPackagePluginValidation`,
   `-skipMacroValidation` and `CODE_SIGNING_ALLOWED=NO`, and filters output through xcbeautify.
2. Report ONLY:
   - the final line (`xcb.sh: build <platform> OK` or `FAILED (xcodebuild exit N)`),
   - each `error:` line with `file:line:col` and message (deduplicated), and
   - warnings only if they are new in files you touched.
   Never paste the whole log. If the filtered output is empty but the status is non-zero, `Read` the last 60 lines
   of the raw log path printed by the wrapper (`build/xcresults/<...>.log`).
3. If it fails: fix the root cause in source, then rerun. Do not suppress errors (`try!`, `@unchecked Sendable`,
   `// swiftlint:disable`, lowering `SWIFT_STRICT_CONCURRENCY`, editing the pbxproj) — those need human sign-off.
4. If the failure is a package/plugin trust or macro validation error, say so; the wrapper already passes the skip
   flags, so the fix is in `Package.resolved`/dependencies (ask before changing them).
5. If no simulator matches `SIM_IOS_NAME` / `SIM_TVOS_NAME`, the wrapper falls back to a name-based destination;
   if xcodebuild then reports "Unable to find a destination", run `scripts/sim.sh devicetypes` and tell the user
   which env var to set (INSTALL.md > Placeholders).

## Done means

`scripts/xcb.sh build ios` (and `tvos` when shared UI changed) exits 0 and `.claude/last-build.json` shows
`"status": 0`. The Stop hook (`.claude/hooks/stop-gate.sh`) re-checks this before the turn can end.

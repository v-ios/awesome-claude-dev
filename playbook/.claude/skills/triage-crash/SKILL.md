---
name: triage-crash
description: "Triage a crash from a .ips/.crash report: symbolicate, locate the frames in source, reproduce with a failing test, fix the root cause, and write a triage summary. Use when given a crash log, a Crashlytics/TestFlight report, or an EXC_* / fatalError stack."
argument-hint: "<path/to/report.ips|.crash> [--dsym App.app.dSYM]"
allowed-tools: Bash(scripts/symbolicate.sh *), Bash(xcrun crashlog *), Bash(atos *), Bash(dwarfdump *), Bash(scripts/xcb.sh *), Bash(scripts/xcresult-failures.sh *), Read, Grep, Glob
---

<!-- composed: not from official docs; symbolication commands are verbatim from Apple's "Adding identifiable symbol names to a crash report" as quoted in research/notes/apple_platform_tooling.md §6; the prompt shape follows the official "write a failing test that reproduces the issue, then fix it ... address the root cause, don't suppress the error" guidance. -->

## Report head

!`head -n 60 "$0" 2>/dev/null || echo "pass the report path as the first argument"`

## Steps

1. Symbolicate if frames show raw addresses:
   - with the matching dSYM: `scripts/symbolicate.sh <report> --dsym <App.app.dSYM> --out build/symbolicated.ips`
     (runs Xcode's `CrashSymbolicator.py <report> -d <dSYM>`; handles JSON .ips and inlined frames)
   - without a dSYM path: `scripts/symbolicate.sh <report>` (`xcrun crashlog <report>`; needs the dSYM findable by Spotlight)
   - one stubborn frame: `scripts/symbolicate.sh --atos --dsym <App.app.dSYM> --load <load-address> <addr>...`
     (`atos -arch arm64 -o <dSYM>/Contents/Resources/DWARF/<binary> -l <load> -i <addr>`)
   - dSYM mismatch? `scripts/symbolicate.sh --uuid --dsym <App.app.dSYM>` and compare with the report's binary UUID.
   - Reports need a `.ips` or `.crash` extension; the script copies/renames if not.
2. Identify: exception type and codes, crashed thread, the first 3 app frames (not framework frames), and the
   trigger (`Application Specific Information`, last breadcrumb, `fatalError` message). Note whether it is a
   main-thread checker violation, `EXC_BAD_ACCESS` (dangling reference / data race), `EXC_BREAKPOINT` (force
   unwrap, `try!`, `precondition`), watchdog (`0x8badf00d`), or OOM.
3. Locate: `Grep` for the symbol names in the top app frames; `Read` the surrounding code; look for the usual
   suspects — non-Sendable state mutated off the main actor, `[weak self]` missing or `unowned` captures,
   force unwraps, array index assumptions, `Task` outliving its owner, SwiftData access from the wrong context,
   tvOS focus callbacks touching deallocated views.
4. Reproduce first: write a Swift Testing test (`Tests/<Module>Tests/...`) that fails the same way (crashes
   or `#expect` on the precondition), run it with `scripts/xcb.sh test ios --only-testing <Target/Class/test>`
   and confirm it fails for the right reason.
5. Fix the root cause. Never suppress: no `try?` to hide a throw, no `if let` that silently skips the work, no
   `@unchecked Sendable`, no `DispatchQueue.main.async` sprinkled as a guess. If the cause is a data race, fix the
   isolation (`@MainActor`, actor, `Sendable` value) and explain why.
6. Rerun the test (green), then `/build ios` and `/build tvos`, then the surrounding test class.
7. Output the triage summary below and propose the commit message. Do not commit or open a PR unless asked.

## Triage summary template

```
Crash: <exception type / signal> in <App> <version (build)> on <OS> <device>
Thread: <n> (<main|background>)   Reproducible: <always|intermittent|unknown>
Top app frames:
  1. <Module.Type.method> (<file>:<line>)
  2. ...
Root cause: <one or two sentences; what invariant was violated and why>
Fix: <what changed, file:line; why it is the root cause and not a symptom>
Regression test: <Tests/...Tests.swift: `test name`> — fails before, passes after
Verification: scripts/xcb.sh test ios --only-testing <...> OK; build ios OK; build tvos OK
Follow-ups / risk: <other call sites with the same pattern, migration needs, monitoring>
```

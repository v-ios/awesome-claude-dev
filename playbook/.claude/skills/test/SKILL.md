---
name: test
description: Run the narrowest useful test set (-only-testing) for iOS or tvOS through scripts/xcb.sh, then summarize failures from the .xcresult with the Xcode 16+ xcresulttool interface. Use after writing or changing tests, or when asked whether tests pass.
argument-hint: "[ios|tvos] [TestTarget[/TestClass[/testMethod]]] [--xctestrun PATH]"
allowed-tools: Bash(scripts/xcb.sh *), Bash(scripts/xcresult-failures.sh *), Bash(xcrun xcresulttool *), Read, Grep
---

<!-- composed: not from official docs; xcodebuild/xcresulttool syntax is verbatim from research/notes/apple_platform_tooling.md §1. -->

## Steps

Arguments: `$ARGUMENTS` — platform (default `ios`) and an optional test identifier
`TestTarget[/TestClass[/TestMethod]]` (CLAUDE.md > "narrowest check that can fail").

1. Pick the narrowest identifier that covers your change (one method > one class > one target > whole scheme).
2. Run `scripts/xcb.sh test <platform> --only-testing <identifier>` (repeat `--only-testing` for several).
   - Re-running a single failing test without recompiling: first `scripts/xcb.sh build-for-testing <platform>`
     (produces an `.xctestrun` under `.derivedData/Build/Products/`), then
     `scripts/xcb.sh test-without-building <platform> --xctestrun <path> --only-testing <identifier>`.
   - Package-only logic: `swift test --filter <SuiteName>` inside the package is faster than xcodebuild.
3. The wrapper prints the compact summary. If anything failed, it already ran
   `scripts/xcresult-failures.sh <bundle>`; read its output, not the raw log.
4. If you need more detail, use the Xcode 16+ interface directly (the legacy `xcresulttool get --format json`
   errors without `--legacy`):
   - `xcrun xcresulttool get test-results summary --path <bundle>.xcresult --compact`
   - `xcrun xcresulttool get test-results tests --path <bundle>.xcresult --compact`
   - `xcrun xcresulttool get test-results test-details --path <bundle>.xcresult --test-id <id> --compact`
   - `xcrun xcresulttool get test-results activities --path <bundle>.xcresult --test-id <id>`
   - `xcrun xcresulttool export attachments --path <bundle>.xcresult --output-path ./build/attachments --only-failures`
   - `xcrun xcresulttool get log --path <bundle>.xcresult --type console --compact | tail -n 80`
   Schema for any subcommand: `xcrun xcresulttool help get test-results <subcommand>`.
5. Report: pass/fail counts, then for each failure `Target/Class/method — message — file:line` and the fix you
   intend. Exported failure screenshots can be `Read` directly.
6. Fix the code, not the test. Never weaken or disable an assertion to go green; if the test is wrong, say why
   and ask.

## Rules that apply

`.claude/rules/testing.md` (Swift Testing vs XCTest per target, naming, no sleep). Test target names are
placeholders in INSTALL.md; `scripts/xcb.sh list` prints the real schemes.

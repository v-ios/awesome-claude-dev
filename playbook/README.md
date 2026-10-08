# Claude Code playbook for native iOS + tvOS (Swift/Xcode) — file index

Copy-in template for an app repository (see **INSTALL.md** for what goes where, versions, placeholders and a
30-minute quickstart). Every file below is derived from, and cross-referenced to, the research notes in
`research/notes/`:
**GOV** = governance_and_context_engineering.md · **TOOL** = apple_platform_tooling.md ·
**DAILY** = daily_workflows_and_sessions.md · **CASES** = practitioner_case_studies.md · **GN** = gitnexus_evaluation.md.
Files marked *composed* assemble documented syntax into something the notes did not show verbatim; validate in your repo.

| File | What it is | Derived from |
| --- | --- | --- |
| `README.md` | this index: every file and the research-note section it derives from | all five notes |
| `INSTALL.md` | copy map, min versions (Claude Code 2.1.293+, auto mode default 2.1.283), prerequisites, placeholders, quickstart | GOV KQ1-4 + appendix; TOOL §4 |
| `CLAUDE.md` | project memory template (< 200 lines): wrapper commands, narrowest-check table, layer rule, Swift 6 / SwiftUI / tvOS guidance, human sign-off list, session hygiene | GOV KQ1 (ios-template AGENTS.md pattern, docs include/exclude table); DAILY KQ2, KQ4, KQ6; CASES KQ4 |
| `.claude/rules/swift.md` | Swift 6 concurrency, error handling, logging, design (`paths: **/*.swift`) | GOV KQ2 (ios-template swift.md); CASES KQ4 |
| `.claude/rules/swiftui.md` | body splitting, `@Observable`, previews, focus APIs, a11y/l10n | CASES KQ1/KQ4 (type-checker timeouts); TOOL §5 (focus APIs) |
| `.claude/rules/architecture.md` | layer table with the gate that enforces each boundary | GOV KQ2, KQ8 (enforce twice) |
| `.claude/rules/testing.md` | Swift Testing vs XCTest per target, targeted invocation, naming | GOV KQ2 (ios-template testing.md); CASES KQ2 (Duolingo mixing); TOOL §1 |
| `.claude/rules/tvos.md` | focus engine, Siri Remote, parallax, Top Shelf, verification steps | TOOL §2, §5; CASES tvOS note |
| `.claude/rules/xcode-project.md` | pbxproj/lockfile/plist/entitlements policy and the hook that enforces it | GOV KQ2 (project.md), KQ3; TOOL §3 (Package.resolved, CocoaPods) |
| `.claude/settings.json` | allow/ask/deny rules tuned for Xcode + hook wiring (exact hook schema) | GOV KQ3 (config structure, matchers, timeout), KQ4 (rule syntax, composed Swift settings) |
| `.claude/hooks/protect-files.sh` | PreToolUse block of generated/locked/signing files (exit 2) | GOV KQ3 (official protect-files.sh) |
| `.claude/hooks/guard-bash.sh` | PreToolUse Bash guard: force push, rm -rf outside build dirs, xcodebuild clean (ask), pod deintegrate; bypass caveat | GOV KQ3 (exit codes, permissionDecision JSON), KQ4 (rule limits, sandbox) |
| `.claude/hooks/format-swift.sh` | PostToolUse swiftformat + swiftlint on the edited file, exit 2 so Claude fixes | GOV KQ3 (ios-template format-edited-file.sh rationale), KQ8 |
| `.claude/hooks/session-start.sh` | SessionStart status (git, last build, simulators) into context | GOV KQ3 (SessionStart stdout semantics; composed session-status.sh) |
| `.claude/hooks/stop-gate.sh` | Stop gate: quiet build when Swift changed; `stop_hook_active`; 8-continuation cap | GOV KQ3 (Stop input/output, cap); DAILY KQ6 (build at checkpoints) |
| `.claude/skills/build/SKILL.md` | `/build ios\|tvos\|both` via `scripts/xcb.sh`, errors only | GOV KQ5 (skill frontmatter, composed build-and-test); TOOL §1 |
| `.claude/skills/test/SKILL.md` | `/test` with `-only-testing` + Xcode 16+ xcresulttool | TOOL §1 (xcodebuild, xcresulttool verbatim) |
| `.claude/skills/run-sim/SKILL.md` | boot/install/launch/screenshot/read; MobileBuildMCP and mcpbridge alternatives | TOOL §2, §4; CASES KQ3 (close the loop) |
| `.claude/skills/triage-crash/SKILL.md` | symbolicate (crashlog / CrashSymbolicator.py / atos), reproduce with a failing test, fix root cause | TOOL §6; DAILY KQ3 (bug-triage prompt structure) |
| `.claude/skills/tvos-focus-debug/SKILL.md` | focus logging, UIFocusDebugger via lldb batch, Device Hub/idb input, XCUIRemote, checklist | TOOL §5, §6 |
| `.claude/skills/review-pr/SKILL.md` | Swift/tvOS review with `!` diff injection, severity-tagged output | GOV KQ5 (`!` injection), KQ6, KQ9 |
| `.claude/skills/release-check/SKILL.md` | version/build bump, changelog, export plist, signing needs a human; `disable-model-invocation` | GOV KQ5 (composed release-checklist); CASES KQ3 (release automation) |
| `.claude/agents/swift-reviewer.md` | opus reviewer subagent (concurrency, memory, SwiftUI perf, tvOS, architecture) | GOV KQ6 (frontmatter, composed swift-reviewer) |
| `.claude/agents/swift-test-writer.md` | sonnet Swift Testing writer, fakes not mocks, test-first | GOV KQ6; CASES KQ2 (Duolingo failure modes) |
| `.claude/agents/architecture-guardian.md` | haiku read-only boundary check (`disallowedTools: Edit, Write`) | GOV KQ6, KQ8 |
| `.claude/agents/tvos-focus-debugger.md` | sonnet focus investigator (lldb, screenshots, logs) | TOOL §5 |
| `.mcp.json` | MobileBuildMCP (`npx -y mobilebuildmcp@latest mcp`) + Xcode `xcrun mcpbridge` | GOV KQ7 (.mcp.json format, env expansion); TOOL §4 |
| `.swiftlint.yml` | strict baseline, opt-in memory/force-unwrap rules, analyzer rules, custom import-ban rules | GOV KQ8 (README keys, ios-template custom rules); TOOL §1 |
| `.swiftformat` | ios-template options + composed extras | GOV KQ8 |
| `REVIEW.md` | review guidelines (managed Code Review, `/review-pr`, `scripts/claude-review.sh`) | GOV KQ9 (REVIEW.md shape, composed Swift version) |
| `scripts/xcb.sh` | xcodebuild wrapper: destination resolution, result bundles, xcbeautify, summary, status file | TOOL §1, §3 (flags verbatim; inferred command line) |
| `scripts/sim.sh` | simctl helpers, Apple TV aware, tvOS input notes | TOOL §2 |
| `scripts/xcresult-failures.sh` | failing tests/messages/attachments from `.xcresult` (Xcode 16+ syntax) | TOOL §1 (xcresulttool man page) |
| `scripts/symbolicate.sh` | `.ips` + dSYM via CrashSymbolicator.py / crashlog; atos fallback; dwarfdump --uuid | TOOL §6 |
| `scripts/arch-check.sh` | grep-based import-boundary checker with allowlist map (CI + guardian) | GOV KQ8 (ios-template regex, architecture-lint pattern) |
| `scripts/claude-review.sh` | headless `claude -p` review with json output, schema, budget, dontAsk, restricted tools | GOV KQ9; DAILY KQ1 (headless flags) |
| `scripts/eval-context-tool.sh` | A/B harness (baseline vs tool MCP, fresh worktrees, oracle, CSV) with Swift-parse pre-flight | GN KQ2, KQ3, KQ7 |
| `ci/ios-guardrails.yml` | macOS runner: swiftlint strict, swiftformat --lint, arch-check, boundary tests, build+test ios/tvos, upload xcresult | GOV KQ8 (composed CI gate); TOOL §1 |
| `ci/claude-pr-review.yml` | `anthropics/claude-code-action@v1` PR review with Swift/tvOS prompt, path filters, inline-comment tool | GOV KQ9 (verbatim workflow inputs) |
| `Tests/ArchitectureBoundaryTests.swift` | Swift Testing suite scanning sources for banned imports per layer | GOV KQ8 (ios-template ArchitectureBoundaryTests) |

Enforcement layers, from advisory to hard: `CLAUDE.md`/rules (context) -> skills/subagents (procedures) ->
hooks + permission rules (deterministic, text-matched) -> OS sandbox (filesystem/network) -> CI (backstop for
`--no-verify` and anything that slipped through locally).

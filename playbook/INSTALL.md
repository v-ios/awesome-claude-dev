# Install: Claude Code playbook for native iOS + tvOS repos

This directory is a **template** you copy into your own Xcode/Swift repository. It is derived from the
research notes in `research/notes/` (see README.md for the file-by-file
mapping). Nothing here is wired into the host repo.

## Minimum versions

- **Claude Code >= 2.1.293.** Path-scoped `.claude/rules/*.md` load on Write/Edit only since 2.1.288 and on
  single-file `cat/head/sed -n/grep` views since 2.1.293; the rules here rely on both. `/doctor prompt-audit`
  needs 2.1.283+. Check with `claude --version`; update with `claude update`.
- **Auto mode is the default starting permission mode since 2.1.283.** `.claude/settings.json` sets
  `permissions.defaultMode` to `acceptEdits` so commands outside the allow list still prompt; delete that key
  if your team prefers auto mode. Deny rules apply in every mode, including `bypassPermissions`.
- **Xcode 16+** (Xcode 26.x recommended; **26.3+** for the `xcrun mcpbridge` MCP server), macOS 14.5+.

## Prerequisites (brew unless noted)

| Tool | Why | Install |
| --- | --- | --- |
| `jq` | hooks parse stdin JSON (python3 fallback exists, jq is faster) | `brew install jq` |
| `xcbeautify` | `scripts/xcb.sh` filters xcodebuild output (`--quiet`); falls back to grep | `brew install xcbeautify` |
| `swiftlint`, `swiftformat` | PostToolUse hook + CI (`.swiftlint.yml`, `.swiftformat`) | `brew install swiftlint swiftformat` |
| MobileBuildMCP (optional) | headless build/test/simulator/UI-automation MCP; Node 18+ | runs via `npx -y mobilebuildmcp@latest mcp` from `.mcp.json` |
| Xcode 26.3 MCP (optional) | IDE tools (previews, issue navigator, Xcode 27 debugger/simulator) | Xcode > Settings > Intelligence > "Allow external agents to use Xcode tools"; keep the project open |
| `idb` (optional, tvOS) | scripted Siri Remote input: `idb ui remote up\|down\|left\|right\|select\|menu` | `brew install facebook/fb/idb` |
| XcodeGen or Tuist (optional) | the pbxproj is generated, never hand-edited | `brew install xcodegen` / `brew install tuist` |

## What to copy where (repo root = the directory with your `.xcodeproj`/`.xcworkspace`)

| From this template | To your repo | Notes |
| --- | --- | --- |
| `CLAUDE.md` | `CLAUDE.md` | edit placeholders; keep < 200 lines; or make it one line `@AGENTS.md` if you already have AGENTS.md |
| `.claude/settings.json` | `.claude/settings.json` | shared; put personal allow rules in gitignored `.claude/settings.local.json` |
| `.claude/rules/*.md` | `.claude/rules/` | adjust the `paths:` globs to your tree; `paths` is the only frontmatter key read |
| `.claude/hooks/*.sh` | `.claude/hooks/` | `chmod +x`; hooks run only after you accept the workspace trust dialog (always in `-p` mode) |
| `.claude/skills/*/SKILL.md` | `.claude/skills/` | `/build /test /run-sim /triage-crash /tvos-focus-debug /review-pr /release-check` |
| `.claude/agents/*.md` | `.claude/agents/` | picked up without restart |
| `.mcp.json` | `.mcp.json` | project-scoped servers; approval prompt on first interactive use (`claude mcp reset-project-choices` to redo) |
| `.swiftlint.yml`, `.swiftformat` | repo root | merge with existing configs; keep `strict: true` |
| `REVIEW.md` | `REVIEW.md` | read by Anthropic's managed Code Review and injected into `/review-pr` and `scripts/claude-review.sh` |
| `scripts/*.sh` | `scripts/` | `chmod +x`; all read env vars, none hardcode scheme names |
| `ci/*.yml` | `.github/workflows/` | set repo variables `SCHEME_IOS`, `SCHEME_TVOS`, ... and the `ANTHROPIC_API_KEY` secret |
| `Tests/ArchitectureBoundaryTests.swift` | your unit-test target (e.g. `Tests/MyAppCoreTests/`) | Swift Testing; edit the module names at the top |

Add to `.gitignore`: `.derivedData/`, `build/`, `.claude/worktrees/`, `.claude/settings.local.json`, `.claude/last-build.json`.

## Placeholders to replace

| Placeholder | Where | Replace with |
| --- | --- | --- |
| `MyApp`, `MyApp-tvOS` | `scripts/xcb.sh` defaults (`SCHEME_IOS`, `SCHEME_TVOS`), `CLAUDE.md`, `ci/ios-guardrails.yml` | your iOS and tvOS scheme names (`xcodebuild -list`) |
| `MyAppCore`, `MyAppUI`, `MyAppPlatform`, `MyAppFeatures`, `App/` | `.swiftlint.yml` custom rules, `scripts/arch-check.sh` built-in rules (or `scripts/arch-rules.conf`), `.claude/rules/architecture.md`, `Tests/ArchitectureBoundaryTests.swift`, `CLAUDE.md` | your module names and source directories |
| `MyAppTests/ArchitectureBoundaryTests` | `ci/ios-guardrails.yml` (`ARCH_TEST_ID`), `.claude/rules/testing.md` | `TestTarget/TestClass` of the boundary suite |
| `com.example.myapp` style bundle ids | `/run-sim`, `/tvos-focus-debug` arguments, `scripts/sim.sh log` predicates | your bundle ids |
| `iPhone 16`, `Apple TV 4K (3rd generation)` | `SIM_IOS_NAME`, `SIM_TVOS_NAME` env defaults | names from `xcrun simctl list devicetypes` on your Xcode |
| `main` | `.claude/skills/review-pr/SKILL.md` injections, `scripts/claude-review.sh` default base | your default branch |
| `./.derivedData`, `./build/xcresults` | `DERIVED_DATA`, `XCRESULT_DIR` | keep, or point at your CI cache location |

## `.claude/settings.json`, explained (JSON cannot carry comments)

- `permissions.allow`: the wrappers, read-only `xcodebuild` queries, `xcrun simctl/xcresulttool/xctrace/crashlog/lldb`, `swift build/test`, lint/format, XcodeGen/Tuist generate, read-only git, `mcp__MobileBuildMCP__*`.
- `permissions.ask`: `git push`, `pod install/update`, `swift package update`, archive/export, `altool`/`notarytool`/`fastlane`, `agvtool new-*`, simulator erase/delete, `rm -rf` (the guard-bash hook auto-allows `rm -rf` of `.derivedData`/`.build`/`build` and blocks everything else), `mcp__xcode__*` (Xcode 27 tools can change build settings).
- `permissions.deny`: edits to `*.pbxproj`, `*.xcworkspacedata`, `Podfile.lock`, `Package.resolved`, `*.entitlements`, `*.mobileprovision`; reads of secrets; force push (all four spellings the rule syntax can express); `pod deintegrate`; `curl`/`wget`.
- Hooks: `PreToolUse` `Edit|Write|MultiEdit` -> `protect-files.sh` (exit 2 = block); `PreToolUse` `Bash` -> `guard-bash.sh` (exit 2 = block, JSON `permissionDecision` ask/allow); `PostToolUse` `Edit|Write|MultiEdit` -> `format-swift.sh` (swiftformat, swiftlint --fix, swiftlint lint; exit 2 so violations reach Claude); `SessionStart` -> `session-start.sh` (stdout becomes context); `Stop` -> `stop-gate.sh` (quiet build if Swift changed; respects `stop_hook_active`; Claude Code caps consecutive continuations at 8, `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` raises it). Each hook has a `timeout` (seconds; default would be 600).
- What rules and hooks do NOT catch: `/bin/rm`, `bash -c '…'`, `git -C . push --force`, `grep -r` over a secret directory. Enable the OS sandbox for that: `/sandbox` in a session, or add
  `"sandbox": {"enabled": true, "filesystem": {"allowWrite": ["~/Library/Developer/Xcode/DerivedData", "~/Library/Developer/CoreSimulator"]}, "network": {"allowedDomains": ["github.com", "*.apple.com"]}}`
  to settings and verify `xcodebuild` still works (no official Xcode-specific sandbox guidance exists; the `allowWrite` list above is composed).
- Env overrides: `CLAUDE_ALLOW_PROTECTED_EDITS=1`, `GUARD_ALLOW_XCODEBUILD_CLEAN=1`, `GUARD_BASH_DISABLED=1`, `STOP_GATE_PLATFORM=both`, `STOP_GATE_MAX_SECONDS=900`, `STOP_GATE_DISABLED=1`.

## `.mcp.json`: keep one or both servers

JSON has no comments, so both servers are listed. To drop one, delete its object from `mcpServers`, or disable it
per machine with `claude mcp remove <name>` / `/mcp disable <name>`. `mobilebuildmcp@latest` is the vendor's documented form; for reproducible sessions pin the exact version your team
tested (2.7.1 at research time) and treat the bump like any dependency bump. The equivalents of the two entries are
`claude mcp add MobileBuildMCP -- npx -y mobilebuildmcp@latest mcp` and
`claude mcp add --transport stdio xcode -- xcrun mcpbridge`. `MOBILEBUILDMCP_ENABLED_WORKFLOWS` defaults to
`simulator`; add `debugging`, `xcode-ide` (Xcode 26.3+ bridge) or the UI-automation workflow as needed — every
advertised tool costs context, so enable only what you use. Call `session_show_defaults` once per session before
the first MobileBuildMCP build. Headless `-p` runs load `.mcp.json` without asking; use `--strict-mcp-config`
with your own `--mcp-config` in scripts (see `scripts/eval-context-tool.sh`).

## 30-minute quickstart

1. (3 min) `brew install jq xcbeautify swiftlint swiftformat`; `claude --version` >= 2.1.293.
2. (5 min) Copy the files per the table above into your repo; `chmod +x scripts/*.sh .claude/hooks/*.sh`.
3. (5 min) Replace placeholders: scheme names, module names, bundle ids, simulator names (`xcrun simctl list devicetypes`).
4. (3 min) `scripts/xcb.sh list` then `scripts/xcb.sh build ios` and `scripts/xcb.sh build tvos`; fix env vars until both pass. `scripts/arch-check.sh --list` must show your real directories.
5. (3 min) `swiftlint lint --strict` and `swiftformat --lint .`; if the baseline is red, fix or (with sign-off) tune `.swiftlint.yml` before enabling the hook, otherwise every edit will exit 2.
6. (3 min) Start `claude`, accept the workspace trust dialog, run `/hooks` (five hooks listed) and `/context` (CLAUDE.md loaded; rules appear when you open a matching file). Open a `.swift` file via `Read` and confirm `swift.md` loaded; if not, run `claude --debug` and check the frontmatter parse.
7. (3 min) `/build ios`, then edit a view and let the PostToolUse hook format/lint it; end the turn and watch the Stop gate build.
8. (3 min) `/run-sim ios <bundle-id>` and read the screenshot; `/run-sim tvos <bundle-id>` and move focus with the arrow keys.
9. (2 min) Add `ci/*.yml` to `.github/workflows/`, set repo variables and `ANTHROPIC_API_KEY`, open a PR, confirm the guardrails job and the Claude review run.
10. Later: `/doctor prompt-audit` after model upgrades; prune CLAUDE.md when Claude already does the right thing without a line.

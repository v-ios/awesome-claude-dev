# awesome-claude-dev

Research and a copy-in playbook for using Claude Code on native iOS and tvOS. The research was done on 2026-10-08 against the Claude Code documentation as it stood that day (describing v2.1.29x) and against Apple's Xcode 26 and Xcode 27 documentation and release notes. It answers four questions (how top-tier mobile engineers run Claude Code day to day, how to close the build/test/simulator loop on Apple platforms, how to keep an agent inside an architecture, and how to adopt all of it in four weeks) plus a fifth on whether the GitNexus code-graph tool is worth adding. Every claim in the research carries an evidence tag (see [Evidence tags](#evidence-tags)), and every playbook file that was composed from documented syntax rather than copied from a working project is marked `composed` and has not been executed against a real Xcode project.

## Start here

- [research/report.md](research/report.md): the full report, "Closed verification loops make Claude Code ship iOS" (about 13,000 words, four objectives, a four-phase adoption plan, and a list of what could not be verified).
- [playbook/INSTALL.md](playbook/INSTALL.md): the copy-in template's versions, prerequisites, copy map, placeholders and 30-minute quickstart; [playbook/README.md](playbook/README.md) indexes every file and the research note it derives from.
- [Part 2 of the report: GitNexus](research/report.md#part-2-gitnexus-parses-swift-but-its-license-and-evidence-gap-demand-a-local-ab): what the tool does, what its Swift and Objective-C support actually covers, its license, the independent evidence, and a method for deciding whether any code-intelligence tool helps on your repository.

## Key findings

- The results come from a closed verification loop, not from prompts. A check Claude can run on its own (an `xcodebuild` exit code, a targeted `-only-testing:` run, a simulator screenshot plus an accessibility dump) is what separates a session you watch from one you walk away from; Anthropic's best-practices page and every first-hand Apple-platform account found (Karunaratne, Trott, Wals, Bartlett, Duolingo, Shopify) say so.
- Plan first and isolate every task. Complex work starts in plan mode, runs as one task per named session or git worktree (`claude -n <task> -w <task>`), and commits at milestones because checkpoints and `/rewind` do not capture Bash-driven changes such as `xcodegen generate` or `pod install`.
- Keep the context window small. It is the resource that degrades first: filter `xcodebuild` output (`-quiet` piped into `xcbeautify -qq --is-ci` or `xcsift`), `/compact` with a focus after each green build, `/clear` between tasks, and keep `CLAUDE.md` under 200 lines.
- `xcodebuild`, Xcode 16+ `xcresulttool` and `simctl` are the backbone; MCP sits on top in layers. Apple's own Xcode MCP server (Xcode 26.3+, `xcrun mcpbridge`, needs the project open in Xcode), Sentry's MobileBuildMCP (works without Xcode running) and small idb or LSP tools (the official `swift-lsp` plugin) each fail differently, and practitioners run two of them together.
- `CLAUDE.md` and `.claude/rules/` are advisory; hooks, permission rules and the OS sandbox enforce. The docs state that CLAUDE.md is "context, not enforced configuration"; a `PreToolUse` hook that exits 2, committed `deny` rules and the Seatbelt sandbox are what actually stop a `.pbxproj` edit, a secret read or a force push.
- Enforce every architectural boundary twice. The strongest real Swift template pairs a SwiftLint custom rule with a Swift Testing suite on different CI jobs, so an agent-written `// swiftlint:disable` still fails the build; CI is the backstop for everything hooks and permissions cannot see.
- tvOS has no published first-hand Claude Code account from any named engineer or company. A workable focus-engine loop can be composed from Apple primitives (`-UIFocusLoggingEnabled YES`, `po UIFocusDebugger.status()`, `XCUIRemote`, Device Hub keyboard mapping, idb's `ui remote`, Xcode 27's Siri Remote tools), but every tvOS recipe here is an [Inference]-tier composition.
- GitNexus does parse Swift and Objective-C as of October 2026 (the brief's assumption that it did not was wrong), but it is PolyForm Noncommercial licensed, its edges are heuristic Tree-sitter resolution rather than compiler-backed, it publishes no Swift accuracy numbers, and the independent evidence for code-graph tools is thin, mixed and Swift-free. The only defensible decision is a paired A/B on your own repository behind a mandatory "did it actually parse Swift" gate.

## Repository map

```text
awesome-claude-dev/
├── README.md                this file
├── CONTRIBUTING.md          what belongs here; evidence-tag and composed-marker rules
├── LICENSE                  MIT
├── research/
│   ├── report.md            the synthesis: four objectives, adoption plan, Part 2 on GitNexus, sources
│   └── notes/
│       ├── daily_workflows_and_sessions.md        sessions, worktrees, headless mode, prompt structures
│       ├── apple_platform_tooling.md              xcodebuild, xcresulttool, simctl, MCP layers, tvOS focus
│       ├── governance_and_context_engineering.md  CLAUDE.md, rules, hooks, permissions, sandbox, review
│       ├── practitioner_case_studies.md           named engineers and companies, with provenance notes
│       └── gitnexus_evaluation.md                 GitNexus source read, license, evidence, A/B design
└── playbook/                copy-in template for an iOS/tvOS app repository
    ├── README.md            file index mapping every file to the research note it derives from
    ├── INSTALL.md           minimum versions, prerequisites, copy map, placeholders, 30-minute quickstart
    ├── CLAUDE.md            project memory template, under 200 lines
    ├── REVIEW.md            review guidelines for managed Code Review, /review-pr and scripts/claude-review.sh
    ├── .claude/             rules/, hooks/, skills/, agents/ and settings.json (permissions plus hook wiring)
    ├── .mcp.json            MobileBuildMCP and Apple's Xcode MCP server (xcrun mcpbridge)
    ├── .swiftlint.yml       strict baseline with custom import-ban rules; .swiftformat alongside it
    ├── scripts/             xcb.sh, sim.sh, xcresult-failures.sh, symbolicate.sh, arch-check.sh,
    │                        claude-review.sh, eval-context-tool.sh
    ├── ci/                  ios-guardrails.yml (macOS runner gates), claude-pr-review.yml (PR review action)
    └── Tests/               ArchitectureBoundaryTests.swift (Swift Testing suite, second boundary enforcement)
```

## Playbook quickstart

The full procedure, including the copy map and the placeholder table, is in [playbook/INSTALL.md](playbook/INSTALL.md#30-minute-quickstart). Prerequisites:

- Claude Code >= 2.1.293 (path-scoped rules fire on writes only from 2.1.288 and on single-file views from 2.1.293); check with `claude --version`.
- Xcode 16+ (Xcode 26.x recommended; 26.3+ for the `xcrun mcpbridge` MCP server), macOS 14.5+.
- `jq`, `xcbeautify`, `swiftlint`, `swiftformat` via Homebrew.
- Optional: MobileBuildMCP (Node 18+, launched from `.mcp.json` as `npx -y mobilebuildmcp@latest mcp`) and the Xcode 26.3 MCP server (Xcode > Settings > Intelligence > "Allow external agents to use Xcode tools"; keep the project open).

Minimal copy-in:

1. `brew install jq xcbeautify swiftlint swiftformat`; confirm `claude --version` is >= 2.1.293.
2. Copy the files per the table in INSTALL.md into the directory that holds your `.xcodeproj` or `.xcworkspace`; `chmod +x scripts/*.sh .claude/hooks/*.sh`.
3. Replace the placeholders: scheme names (`MyApp`, `MyApp-tvOS`), module names (`MyAppCore`, `MyAppUI`, `MyAppPlatform`, `MyAppFeatures`), bundle ids (`com.example.myapp`), simulator names (`iPhone 16`, `Apple TV 4K (3rd generation)`; take the real names from `xcrun simctl list devicetypes`).

The first three commands to run, in order:

```bash
scripts/xcb.sh list          # prints `xcodebuild -list`; confirms SCHEME_IOS / SCHEME_TVOS resolve
scripts/xcb.sh build ios     # quiet build through xcbeautify; fix env vars until it passes
scripts/xcb.sh build tvos    # same for the tvOS scheme
```

Then `scripts/arch-check.sh --list` must show your real directories, `swiftlint lint --strict` and `swiftformat --lint .` must be green before the PostToolUse hook is enabled (otherwise every edit exits 2), and inside `claude` run `/hooks` (five hooks listed) and `/context` (CLAUDE.md loaded; rules appear when a matching file is opened).

## Daily workflow cheat sheet

The launch lines and in-session commands the report lists in Objective 1 ([Official] from the CLI reference, Manage sessions and Worktrees pages):

```bash
# Explore/plan a task without touching source (reads + classifier-approved commands)
claude --permission-mode plan

# One isolated worktree per task, in its own tmux session; branch is worktree-<name>
claude -w fix-crash-1234 --tmux          # add .claude/worktrees/ to .gitignore
# Copy gitignored local files (xcconfig secrets, .xcode.env) into each worktree
printf 'Config/Local.xcconfig\n.xcode.env\n' > .worktreeinclude

# Name sessions like branches; resume by name, by PR, or from the picker
claude -n player-scrub-bug               # or /rename inside the session
claude --resume player-scrub-bug "finish the PR"
claude --from-pr 1234                    # sessions auto-link to PRs Claude created
claude --continue --fork-session         # branch a conversation instead of interleaving it

# Inside a session
/compact Focus on the files changed, the xcodebuild/test commands used, and open TODOs
/clear release-prep                      # names the conversation you are leaving
/btw does Combine's sink retain self here?   # never enters the transcript
/goal xcodebuild test -only-testing:AppTests passes and git status is clean, or stop after 20 turns
/loop 5m check whether CI passed and address any review comments
```

Two caveats from the same pages: resuming restores history, model, permission mode and an active `/goal`, but not `--mcp-config`, `--settings`, `--plugin-dir` or `--add-dir`; and the `/goal` evaluator judges only what Claude surfaces, so ask for the final `BUILD SUCCEEDED` or `TEST FAILED` lines to be printed.

## How to judge a tool like GitNexus

The report's Part 2 method, summarized. The harness that implements it is [playbook/scripts/eval-context-tool.sh](playbook/scripts/eval-context-tool.sh); the design borrows its controls from GitNexus's own `workflow_bench` and the GitLab Knowledge Graph study.

1. Pre-flight Swift-parse gate, or stop. Pin the exact version (`gitnexus@1.6.12` at research time), run `gitnexus analyze`, fail on the stderr line `optional grammar "tree-sitter-swift" is unavailable`, compare indexed symbol counts with `git ls-files | grep -E '\.(swift|m|mm|h)$' | wc -l`, and spot-check ten Swift and five Objective-C symbols (file and line correct, caller precision at least 0.8 against a hand-verified list, separate modules per Xcode target, declarations inside `#if os(tvOS)` findable).
2. Arms, paired on the same task, base commit, model, effort, permission mode and CLAUDE.md text: A0 `baseline_nomcp` (`claude --bare -p` with Grep, Glob, Read and Bash), A1 `swift-lsp`, A2 GitNexus MCP tools only, A3 GitNexus full (hooks and skills), A4 `swift-lsp` plus GitNexus full, because stacking tools has been observed to hurt.
3. A task set the team builds itself, since no iOS benchmark exists: eight to twelve tasks across trivial, investigation, cross-module and UI-plus-network work, mixing Swift-only, Objective-C-only and mixed code, each with a hidden oracle (a reproducing unit test, `build-for-testing` across all targets, an exact call-site set) kept outside the worktree the agent sees.
4. Metrics from `claude -p --output-format json` or `stream-json` (`total_cost_usd`, `num_turns`, wall and API duration, `session_id`) and from OpenTelemetry (`claude_code.token.usage`, `claude_code.cost.usage` attributed by `mcp_server.name`, `claude_code.tool_result` sizes and `tool_name` distribution), plus whether `impact` or `context` output was actually used.
5. Controls: a fresh `git worktree` per run with `.gitnexus/` deleted and re-analyzed, at least five runs per task-arm pair (GitLab used eleven because the API has no per-call seed), randomized order with interleaved arms, `--max-turns` and `--max-budget-usd` caps, and token savings on a failed task flagged rather than celebrated.
6. Pre-registered thresholds and red flags. Write the decision rule before the first run (for example, adopt if the resolve rate improves by at least ten points on cross-module tasks with no cost increase over 20 percent). Stop or discount the study on the Swift-grammar warning or a near-zero Swift node count, `impact` returning unrelated same-name members, stale-index warnings mid-task, Grep latency inflated by the 10-second hook, GitNexus tools listed but called zero or one times while cost rises, resolve rates varying by more than two tasks across repeats, or any use without an Akon Labs license.

## Curated links

Primary sources the research notes rest on, with the access caveat that applies: pages marked "(snippet-only source)" could be reached only as search-engine excerpts, so their quotes are short and should be spot-checked before being reused.

### Official Claude Code docs

- [Best practices](https://code.claude.com/docs/en/best-practices): the verification-loop rule, explore-plan-implement-commit, CLAUDE.md include and exclude lists, the course-correction rule.
- [CLI reference](https://code.claude.com/docs/en/cli-reference): `-w`, `-n`, `--resume`, `--from-pr`, `--effort`, `--bare`, `--allowedTools` and the rest of the launch surface.
- [Hooks reference](https://code.claude.com/docs/en/hooks): 33 events, five handler types, the exit-code contract (only exit 2 blocks), `stop_hook_active`.
- [Subagents](https://code.claude.com/docs/en/sub-agents): frontmatter fields, what a fresh subagent context contains, concurrency limit.
- [Memory](https://code.claude.com/docs/en/memory): CLAUDE.md load order, the 200-line target, `.claude/rules/` with `paths:` frontmatter, `/doctor prompt-audit`.
- [Skills](https://code.claude.com/docs/en/skills): `SKILL.md`, `allowed-tools`, `disable-model-invocation`, live shell injection with `` !`cmd` ``.
- [Permissions](https://code.claude.com/docs/en/permissions): rule syntax, deny > ask > allow, and the documented limits of text matching.
- [MCP](https://code.claude.com/docs/en/mcp): `.mcp.json`, variable expansion, `mcp__<server>__<tool>` permissions, output truncation limits.
- [GitHub Actions](https://code.claude.com/docs/en/github-actions): the `code-review` plugin workflow and the `--allowedTools` line that makes inline comments work.
- [Run Claude Code programmatically](https://code.claude.com/docs/en/headless): `-p`, `--output-format json`, `--bare`, `--permission-mode dontAsk`, the fan-out shell loop.

### Apple tooling

- [xcodebuild(1)](https://keith.github.io/xcode-man-pages/xcodebuild.1.html): `-only-testing`, `-quiet`, `-resultBundlePath`, `build-for-testing` and `test-without-building` (man-page mirror).
- [xcresulttool(1)](https://keith.github.io/xcode-man-pages/xcresulttool.1.html): the Xcode 16+ `get test-results summary|tests|test-details` and `export attachments` forms (man-page mirror).
- [MobileBuildMCP source](https://github.com/getsentry/MobileBuildMCP/tree/main/src): the exact `xcrun simctl` invocations a working agent server shells out to; Apple publishes no web reference for `simctl`.
- [Giving external agents access to Xcode](https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode): the Xcode 26.3 Intelligence setting and `claude mcp add --transport stdio xcode -- xcrun mcpbridge`.
- [Xcode 26.3 Release Notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-26_3-release-notes): the agentic-coding introduction and its known issues (connection dialogs, `/skill` invocation, folder-access denial).
- [Xcode 27 Release Notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes): debugger and simulator MCP tools, tvOS Siri Remote verification, `lldb-mcp`, the headless `xcrun mcp-server` preview.
- [UIFocusDebugger](https://developer.apple.com/documentation/uikit/uifocusdebugger): `status()`, `checkFocusability(for:)`, `simulateFocusUpdateRequest(from:)`, used from lldb.
- [About focus interactions for Apple TV](https://developer.apple.com/documentation/uikit/about-focus-interactions-for-apple-tv): the engine's rules, `movementDidFailNotification`, `preferredFocusEnvironments`.
- [XCUIRemote](https://developer.apple.com/documentation/xcuiautomation/xcuiremote): programmatic Siri Remote presses in UI tests (Xcode 16.3+); swipes cannot be simulated.
- [Adding identifiable symbol names to a crash report](https://developer.apple.com/documentation/xcode/adding-identifiable-symbol-names-to-a-crash-report): `xcrun crashlog`, `CrashSymbolicator.py`, `atos`.

### MCP servers and tools

- [getsentry/MobileBuildMCP](https://github.com/getsentry/MobileBuildMCP): the renamed XcodeBuildMCP; 70-plus tools grouped into workflows, only `simulator` enabled by default, tvOS and Xcode 27 Device Hub support.
- [joshuayoes/ios-simulator-mcp](https://github.com/joshuayoes/ios-simulator-mcp): idb-based simulator server; `SIMCTL_CHILD_` environment prefix; versions below 1.3.3 had command-injection vulnerabilities.
- [facebook/idb](https://github.com/facebook/idb): `idb ui describe-all` for accessibility dumps and the `idb ui remote up|down|left|right|select|menu` command on `main` (not confirmed in a tagged release).
- [swift-lsp plugin](https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/plugins/swift-lsp/README.md): go-to-definition, references, call hierarchy and post-edit diagnostics; terminal sessions only; see also [Code intelligence plugins](https://code.claude.com/docs/en/plugins/code-intelligence).
- [cpisciotta/xcbeautify](https://github.com/cpisciotta/xcbeautify): `-q`, `-qq`, `--is-ci`, the `NSUnbufferedIO=YES ... 2>&1 | xcbeautify` form.
- [ldomaradzki/xcsift](https://github.com/ldomaradzki/xcsift): agent-oriented xcodebuild filter, TOON output, Claude Code plugin, `xcsift mcp -- xcrun mcpbridge` proxy.
- [realm/SwiftLint](https://github.com/realm/SwiftLint): `strict`, `custom_rules` for import bans, analyzer rules that need a compiler log.
- [swiftlang/swift-format](https://github.com/swiftlang/swift-format): Apple's formatter and rule docs; the playbook's `.swiftformat` file targets the separate `swiftformat` CLI instead, which the notes cite only through ios-template.

### Templates and practitioner write-ups

- [tomada1114/ios-template](https://github.com/tomada1114/ios-template): the strongest real Swift template read in full; `CLAUDE.md` is the single line `@AGENTS.md`, path-scoped rules, an exit-2 formatter hook, every boundary enforced twice.
- [Boris Cherny tips (SKZL-AI compilation)](https://raw.githubusercontent.com/SKZL-AI/boris-cherny-claude-code-playbook/main/TIPS.md): worktrees, plan mode, verification, the six-month CLAUDE.md reset; secondhand, with post IDs and dates.
- [Thariq Shihipar interview](https://creatoreconomy.so/p/how-i-plan-build-and-run-loops-with-claude-code-thariq-shihipar): `/goal` only with a verifiable finish line; re-audit instruction files after model upgrades; largely paywalled.
- [Indragie Karunaratne](https://www.indragie.com/blog/i-shipped-a-macos-app-built-entirely-by-claude-code): a shipped macOS app with under 1,000 of 20,000 lines written by hand; "okay at Swift and good at SwiftUI" (snippet-only source).
- [Peter Steinberger, Just Talk To It](https://steipete.me/posts/just-talk-to-it): the reversal; "models will get around a hook if they're determined to" (snippet-only source).
- [Chris Trott, Closing the Loop on iOS](https://twocentstudios.com/2025/12/27/closing-the-loop-on-ios-with-claude-code/): build, install, console, simulator control and device stages (snippet-only source).
- [Donny Wals, delivery pipeline for agentic iOS projects](https://www.donnywals.com/setting-up-a-delivery-pipeline-for-your-agentic-ios-projects/): crash report in, reviewable PR out; a rulebook that grows with every unwanted behavior (snippet-only source).
- [Jacob Bartlett, Advanced Agentic Engineering](https://blog.jacobstechtavern.com/p/advanced-agentic-engineering): "automatic verification is the backbone of agent parallelism" (snippet-only source).
- [Duolingo iOS unit-test pipeline](https://blog.duolingo.com/ai-ios-unit-test-generation-pipeline/): 250 accepted PRs and about 85,000 lines of tests in 17 weeks after rewriting the rules for known failure modes (snippet-only source).
- [Shopify Helix](https://shopify.engineering/helix) and [Shop app migration](https://shopify.engineering/shop-app-migration): checkpointed native rebuild in 12 weeks; "Agentic control of simulators has been a bottleneck" (snippet-only source).

### Tool evaluation

- [GitNexus repository](https://github.com/abhigyanpatwari/GitNexus): Tree-sitter code graph with 19 MCP tools, Claude Code hooks and skills; PolyForm Noncommercial 1.0.0; Swift and Objective-C providers read at commit `ff922c0`.
- [GitNexus on npm](https://registry.npmjs.org/gitnexus): 988 versions in eight months at research time; pin an exact version for any evaluation.
- [GitLab Knowledge Graph study, issue #224](https://gitlab.com/gitlab-org/rust/knowledge-graph/-/issues/224): SWE-Bench Lite, 11 runs per configuration; fewer tool calls and less time, 5 percent more tokens, stacking performed worse than expected.
- [arXiv 2603.27277](https://arxiv.org/pdf/2603.27277): tree-sitter knowledge graphs over MCP; 90 percent of the explorer agent's quality at far fewer tokens, graded by its first author (snippet-only source).
- [Sourcegraph CodeScaleBench](https://raw.githubusercontent.com/sourcegraph/codescalebench/main/README.md): vendor benchmark run through the Claude Code harness; no languages listed, Swift not mentioned.

## Evidence tags

Every claim in `research/` carries one of these tags; the full table is in the report's [evidence-tier section](research/report.md#three-evidence-tiers-govern-every-claim-in-this-report).

| Tag | Meaning |
|---|---|
| [Official] | Read live from code.claude.com or developer.apple.com (docs, release notes, man-page mirrors, DTS forum answers) |
| [Source] | Repository source, README or changelog read directly from GitHub or npm |
| [Snippet] | Practitioner page reachable only as a search excerpt; wording is short and should be spot-checked before quoting |
| [Secondhand] | Quoted via a third-party compilation or press coverage, not the primary post |
| [Inference] | Composed by the researchers from documented syntax for a Swift/tvOS project; not executed |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md): every research claim needs a URL and an evidence tag, and every composed playbook file needs a `composed:` marker and the Claude Code and Xcode versions it was validated against.

## License

[MIT](LICENSE).

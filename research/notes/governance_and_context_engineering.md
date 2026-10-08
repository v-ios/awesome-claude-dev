# Governance and context engineering for Claude Code in native iOS/tvOS (Swift) codebases

Research date: 2026-10-08. Official docs were read live from code.claude.com (they describe Claude Code v2.1.29x; the GitHub CHANGELOG's newest heading on this date is `## 2.1.294`). Where a practitioner page could not be fetched (DNS blocked through the research proxy), it is listed under Gaps rather than paraphrased from search snippets.

Convention used below: "**Verbatim**" blocks are copied from the cited source. "**Composed**" blocks are assembled by me from the cited syntax for a Swift/tvOS project and have NOT been executed; they are playbook starting points, not tested artifacts.

---

## Key question 1: CLAUDE.md — hierarchy, imports, length, `/init`, `#`, `/memory`, Swift content, anti-patterns

### Takeaway
CLAUDE.md is loaded every session as *context, not enforced configuration*; Anthropic's own guidance is to keep each file under ~200 lines, put only facts Claude cannot infer (build commands, conventions, "always do X"), push path-specific material into `.claude/rules/` and procedures into skills, and use hooks for anything that must happen with zero exceptions. A real Swift template (tomada1114/ios-template) demonstrates the pattern: `CLAUDE.md` is a single line `@AGENTS.md`, the shared guide holds build commands, a "narrowest check that can fail" table, the layer diagram, and a "needs human sign-off" list, while per-path rules carry the detailed Swift conventions.

### Cited Findings

**Hierarchy and locations**
- Load order and locations (verbatim table from docs): Managed policy — macOS `/Library/Application Support/ClaudeCode/CLAUDE.md`, Linux/WSL `/etc/claude-code/CLAUDE.md`, Windows `C:\Program Files\ClaudeCode\CLAUDE.md`; User — `~/.claude/CLAUDE.md`; Project — `./CLAUDE.md` or `./.claude/CLAUDE.md`; Local — `./CLAUDE.local.md` ("add to `.gitignore`"). "The table below lists them in load order, from broadest scope to most specific, so a project instruction appears in context after a user instruction." — [Claude Code docs: memory](https://code.claude.com/docs/en/memory)
- "Claude Code loads `CLAUDE.md` and `CLAUDE.local.md` from your current working directory and every directory above it… All discovered files are concatenated into context rather than overriding each other… content is ordered from the filesystem root down to your working directory… Within each directory, `CLAUDE.local.md` is appended after `CLAUDE.md`." — [memory](https://code.claude.com/docs/en/memory)
- Nested files load lazily: "Claude also discovers `CLAUDE.md` and `CLAUDE.local.md` files in subdirectories under your current working directory. Instead of loading them at launch, Claude Code includes them when Claude uses the Read, Write, or Edit tool on a file in those subdirectories." — [memory](https://code.claude.com/docs/en/memory)
- A nested-CLAUDE.md loading bug was fixed late: "2.1.288 — Fixed path-scoped `.claude/rules` and nested CLAUDE.md files not loading when Write or Edit creates or changes a file in their scope (previously only Read loaded them)"; and "2.1.293 — Fixed path-scoped rules and nested CLAUDE.md files not loading when Claude views a file with a single-file cat, head, tail, sed -n or grep command in the Bash tool instead of the Read tool". — [anthropics/claude-code CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)
- Managed CLAUDE.md "cannot be excluded by individual settings"; alternatively "The `claudeMd` key lets you put managed CLAUDE.md content directly inside `managed-settings.json`". Docs' split: "Use settings for technical enforcement and CLAUDE.md for behavioral guidance" (table rows: "Code style and quality guidelines → Managed CLAUDE.md", "Behavioral instructions for Claude → Managed CLAUDE.md"). — [memory](https://code.claude.com/docs/en/memory)
- `claudeMdExcludes` exists to skip other teams' CLAUDE.md files in monorepos. — [memory](https://code.claude.com/docs/en/memory)
- HTML comments are stripped: "Block-level HTML comments (`<!-- maintainer notes -->`) in CLAUDE.md files are stripped before the content is injected into Claude's context." — [memory](https://code.claude.com/docs/en/memory)
- AGENTS.md: Claude "can also read a repository's `AGENTS.md` files in place of CLAUDE.md". — [memory](https://code.claude.com/docs/en/memory)
- `--add-dir` directories do not load CLAUDE.md by default; `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` makes Claude load "`CLAUDE.md`, `.claude/CLAUDE.md`, `.claude/rules/*.md`, and `CLAUDE.local.md` from the additional directory." — [memory](https://code.claude.com/docs/en/memory)

**`@file` imports**
- "CLAUDE.md files can import additional files using `@path/to/import` syntax. Imported files are expanded and loaded into context at launch… Relative paths resolve relative to the file containing the import, not the working directory. Imported files can recursively import other files, with a maximum depth of four hops." — [memory](https://code.claude.com/docs/en/memory)
- Verbatim example:
  ```text
  See @README for project overview and @package.json for available npm commands for this project.

  # Additional Instructions
  - git workflow @docs/git-instructions.md
  ```
  and home-directory import `- @~/.claude/my-project-instructions.md`. Paths with spaces need backslashes; quoted paths are not imported; backtick-wrapped `@README` is literal. — [memory](https://code.claude.com/docs/en/memory)
- External imports (resolving outside the working directory) trigger a one-time approval dialog per project; user-scope files (`~/.claude/CLAUDE.md`, `~/.claude/rules/`) are trusted without a dialog. — [memory](https://code.claude.com/docs/en/memory)
- Imports do NOT save context: "Imports help you organize a long file but don't reduce its context cost, because imported files also load at launch." — [memory](https://code.claude.com/docs/en/memory)

**Recommended length, content, anti-patterns**
- "Size: target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence." "Claude Code skips a file over 4 MiB." A startup/`/status` warning appears when an instruction file exceeds the recommended length or when files together pass a combined limit. — [memory](https://code.claude.com/docs/en/memory)
- "Claude treats CLAUDE.md files as context, not enforced configuration… To block an action regardless of what Claude decides, use a PreToolUse hook instead." — [memory](https://code.claude.com/docs/en/memory)
- Best-practices include/exclude table (verbatim): Include "Bash commands Claude can't guess", "Code style rules that differ from defaults", "Testing instructions and preferred test runners", "Repository etiquette (branch naming, PR conventions)", "Architectural decisions specific to your project", "Developer environment quirks (required env vars)", "Common gotchas or behaviors that aren't self-evident". Exclude "Anything Claude can figure out by reading code", "Standard language conventions Claude already knows", "Detailed API documentation (link to docs instead)", "Information that changes frequently", "Long explanations or tutorials", "File-by-file descriptions of the codebase", "Self-evident practices like 'write clean code'". — [best-practices](https://code.claude.com/docs/en/best-practices)
- "Keep it concise. For each line, ask: 'Would removing this cause Claude to make mistakes?' If not, cut it. Bloated CLAUDE.md files cause Claude to ignore your actual instructions!" and "If Claude keeps skipping one instruction, add emphasis such as 'IMPORTANT' to that line alone. If you emphasize many lines, none of them stands out." — [best-practices](https://code.claude.com/docs/en/best-practices)
- Named failure pattern: "The over-specified CLAUDE.md. If your CLAUDE.md is too long, Claude ignores half of it because important rules get lost in the noise. Fix: Ruthlessly prune. If Claude already does something correctly without the instruction, delete it or convert it to a hook." — [best-practices](https://code.claude.com/docs/en/best-practices)
- Write verifiable instructions: "'Use 2-space indentation' instead of 'Format code properly'… 'API handlers live in `src/api/handlers/`' instead of 'Keep files organized'". Conflicting instructions: "Claude may pick one arbitrarily." — [memory](https://code.claude.com/docs/en/memory)
- Anthropic's steering guide (Michael Segner, June 18 2026): "Keep CLAUDE.md under 200 lines, assign an owner, and review changes like code"; treat it "as an overview of the codebase or an index pointing to other files"; "Absolute prohibitions → hooks or permissions, not instructions… A `PreToolUse` hook that exits with code 2 blocks a call. Managed settings are the only way to enforce org-wide guardrails that users can't override." Its method table rates root CLAUDE.md context cost "High", subdirectory CLAUDE.md "Low", rules "Medium", skills/subagents/hooks "Low". — [Steering Claude Code (claude.com blog)](https://claude.com/blog/steering-claude-code-skills-hooks-rules-subagents-and-more)
- Code Review reads CLAUDE.md too: "Code Review reads your repository's `CLAUDE.md` files and treats newly introduced violations as nit-level findings… if your PR changes code in a way that makes a `CLAUDE.md` statement outdated, Claude flags that the docs need updating too." — [code-review](https://code.claude.com/docs/en/code-review)

**Maintenance: `/init`, `#`, `/memory`, `/doctor prompt-audit`, `/context`**
- `/init`: "Initialize project with a `CLAUDE.md` guide. Set `CLAUDE_CODE_NEW_INIT=1` for an interactive flow that also walks through skills, hooks, and personal memory files. If `/init` finds OpenAI Codex or Google Gemini CLI configuration, it offers to carry it over with `/import`". — [commands](https://code.claude.com/docs/en/commands)
- What `/init` generates: "Claude analyzes your codebase and creates a file with build commands, test instructions, and project conventions it discovers. If a CLAUDE.md already exists, `/init` suggests improvements rather than overwriting it." With `CLAUDE_CODE_NEW_INIT=1`, "`/init` asks which artifacts to set up: CLAUDE.md files, skills, and hooks. It then explores your codebase with a subagent, fills in gaps via follow-up questions, and presents a reviewable proposal before writing any files." Choosing the personal option creates a gitignored `CLAUDE.local.md`. — [memory](https://code.claude.com/docs/en/memory)
- `/memory`: "Edit `CLAUDE.md` files, enable or disable auto memory, and view auto memory entries". It "lists your CLAUDE.md, CLAUDE.local.md, and other memory file locations across user and project scopes… Select any file to open it in your editor". — [commands](https://code.claude.com/docs/en/commands), [memory](https://code.claude.com/docs/en/memory)
- The `#` shortcut is NOT documented on the current memory page. The current mechanism: "When you ask Claude to remember something, like 'always use pnpm, not npm'… Claude saves it to auto memory. To add instructions to CLAUDE.md instead, ask Claude directly, like 'add this to CLAUDE.md,' or edit the file yourself via `/memory`." Auto memory loads "first 200 lines or 25KB" per session, lives at `~/.claude/projects/<project>/memory/`, toggled via `/memory` or `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`. — [memory](https://code.claude.com/docs/en/memory)
- Audit: "run `/doctor prompt-audit` in a session. Claude looks for problems such as instructions written for older models, references to files or commands that don't exist, and files that contradict each other… nothing in your files changes until you ask Claude to apply them." Covers CLAUDE.md, CLAUDE.local.md, AGENTS.md, rules, skills, commands, subagents under `.claude/` and `~/.claude/`. Requires v2.1.283+. `/context` confirms which memory files loaded. — [memory](https://code.claude.com/docs/en/memory)
- `/doctor` on a checked-in CLAUDE.md "proposes cuts for content it can derive from the codebase." — [best-practices](https://code.claude.com/docs/en/best-practices)

**What a strong Swift project actually puts in it (real example)**
- tomada1114/ios-template: `CLAUDE.md` is literally one line, `@AGENTS.md`. — [ios-template CLAUDE.md](https://github.com/tomada1114/ios-template/blob/main/CLAUDE.md)
- Its `AGENTS.md` opens: "This file holds what every agent needs before it knows which task it is on: what the app is, how to check a change, where code goes, and which decisions need a human… the conventions of one kind of change belong to a skill under `.agents/skills/`…; a value a gate enforces belongs to its config (`.swiftlint.yml`, `.swiftformat`, `Package.swift`, `scripts/coverage.sh`, `mise.toml`), and running the gate is how you learn it." — [ios-template AGENTS.md](https://github.com/tomada1114/ios-template/blob/main/AGENTS.md)
- Sections it contains: Overview ("XcodeGen generates the Xcode project from `project.yml`, all real code lives in a local Swift package (`Packages/MyAppKit`), and quality gates (SwiftLint strict, SwiftFormat, Swift 6 language mode, an 80% line-coverage and a 75% function-coverage floor on the Core module) are enforced from day one"); a Quick Reference of `just` recipes (`just build # Build the app (Debug) for the iOS Simulator`, `just test`, `just uitest`, `just lint`, `just check # Run all checks: verify-hooks → fmt → lint → test-scripts → check-harness → test → build`); a "Validating a change" table mapping "What you changed" to "The narrowest check that can fail"; an Architecture tree with the dependency rule "The dependency direction is one-way: Core ← UI and Core ← Platform, both ← App. `MyAppUI` and `MyAppPlatform` are siblings and never import each other."; "`MyApp.xcodeproj` is generated — edit `project.yml` instead."; a Rules table; a Sub-agents paragraph; "Security and human approval" (never read `.env`, `*.p12`, `*.mobileprovision`, `GoogleService-Info.plist`…; sign-off needed before touching entitlements/signing, release tags/TestFlight uploads, new dependencies, "Weakening any gate… `// swiftlint:disable`… `@unchecked Sendable`… `git commit --no-verify`", "Working around a denied command. Re-spelling it (`git -C . …`, `bash -c '…'`…) is forbidden. Stop and ask.", any remote write); an "Enforcement layers" table; a Review Checklist. — [ios-template AGENTS.md](https://github.com/tomada1114/ios-template/blob/main/AGENTS.md)
- The template deliberately ships no committed permission list: "**This repository ships no Claude Code permission list.** There is no committed `.claude/settings.json`: which commands run without a prompt is each person's own choice, in their user-level `~/.claude/settings.json` or the gitignored `.claude/settings.local.json`… The same file is where to register `scripts/format-edited-file.sh` as a `PostToolUse` hook on `Edit|Write|MultiEdit` (`cd "$CLAUDE_PROJECT_DIR" && mise exec -- scripts/format-edited-file.sh`)… a convenience on that host, not a gate." — [ios-template AGENTS.md](https://github.com/tomada1114/ios-template/blob/main/AGENTS.md)
- Community iOS guide (keskinonur/claude-code-ios-dev-guide) CLAUDE.md template sections: Quick Reference (iOS 17+/macOS 14+, Swift 6.0, SwiftUI, MVVM with `@Observable`, SPM); "**IMPORTANT**: This project uses XcodeBuildMCP for all Xcode operations."; Project Structure (`App/`, `Features/` with Views/ViewModels/Models, `Core/` with Extensions/Services/Networking); Coding Standards (Swift 6 strict concurrency, `@Observable` over `ObservableObject`, async/await, value types, `guard` early exits); SwiftUI Patterns (extract views over 100 lines, `NavigationStack` over `NavigationView`, `@Bindable`); Testing (Swift Testing, 80% coverage for business logic); a "DO NOT" list (write UITests during scaffolding, use deprecated UIKit where SwiftUI suffices, force-unwrap without justification, ignore concurrency warnings); `@import`-style memory imports of `docs/PRD.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`; plus a nested feature-level CLAUDE.md. — [keskinonur/claude-code-ios-dev-guide README](https://github.com/keskinonur/claude-code-ios-dev-guide)
- Search-level evidence (snippets only, pages not fetched) of other Swift CLAUDE.md templates that: hardcode `xcodebuild … -destination 'platform=iOS Simulator,name=…'` build/test commands, point to `xcrun simctl list devices available`, say "never modify .pbxproj files", and route builds through XcodeBuildMCP; the templates disagree on Swift 5.9 vs 6.0 and `@Observable` vs `ObservableObject`. — [thepromptshelf.dev guide (search result)](https://thepromptshelf.dev/blog/claude-code-swift-ios-xcode-guide-2026/), [tatejennings.com post (search result)](https://www.tatejennings.com/blog/making-claude-code-work-for-ios-development)

### Inferences
- For an iOS/tvOS playbook the official guidance implies a 3-tier split: root `CLAUDE.md` (<200 lines: build/test commands with exact `xcodebuild` destinations for iOS *and* tvOS simulators, the layer diagram, the "ask a human" list), `.claude/rules/*.md` for per-path Swift/SwiftUI/UIKit/tvOS conventions, and skills for multi-step procedures (release, crash triage). Hard prohibitions (`.pbxproj` edits, lockfile edits, signing files) belong in hooks/permission deny rules, not prose — the memory page says so explicitly.
- Because nested CLAUDE.md loading was only fixed for Edit/Write in 2.1.288 and for Bash views in 2.1.293, playbooks should state a minimum Claude Code version (≥2.1.293) if they rely on nested CLAUDE.md/path rules firing on write.
- The single-line `@AGENTS.md` pattern lets one file serve Claude Code and Codex; the docs also say AGENTS.md can be read directly, so either works.

### Gaps
- The `#` keyboard shortcut to add memory is not on the current memory/commands pages; I could not confirm whether it still exists in 2.1.29x. The documented path is "ask Claude to add this to CLAUDE.md" or `/memory`.
- Could not fetch the full text of tatejennings.com, samwize.com, thepromptshelf.dev, blakecrosley.com (DNS resolution failed through the proxy). Their CLAUDE.md contents are known only from search snippets.
- No official Anthropic Swift-specific CLAUDE.md template exists in the docs.

---

## Key question 2: `.claude/rules/` — format, `paths:` frontmatter, difference from CLAUDE.md, Swift examples, enforcing layering

### Takeaway
`.claude/rules/*.md` was added in Claude Code 2.0.64; files without `paths:` frontmatter load at launch with the same priority as `.claude/CLAUDE.md`, and files with `paths:` globs load only when Claude Reads/Writes/Edits a matching file. `paths` is the only frontmatter key read. Rules are still advisory context; the real Swift example (ios-template) states the import ban in `swift.md` *and* enforces it twice with a SwiftLint custom regex rule and a Swift Testing suite.

### Cited Findings

**Feature history**
- "2.0.64 — Added support for .claude/rules/`. See https://code.claude.com/docs/en/memory for details." — [CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)
- "2.1.69 — Added `InstructionsLoaded` hook event that fires when CLAUDE.md or `.claude/rules/*.md` files are loaded into context" and "Fixed conditional `.claude/rules/*.md` files (with `paths:` frontmatter) and nested CLAUDE.md files not loading in print mode (`claude -p`)". "2.1.198 — Fixed `.claude/rules/` conditional rules not loading when the target file is reached via a symlinked path". "2.1.288 — Fixed path-scoped `.claude/rules`… not loading when Write or Edit creates or changes a file in their scope (previously only Read loaded them)". — [CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)

**Format and semantics (verbatim)**
- Layout:
  ```text
  your-project/
  ├── .claude/
  │   ├── CLAUDE.md           # Main project instructions
  │   └── rules/
  │       ├── code-style.md   # Code style guidelines
  │       ├── testing.md      # Testing conventions
  │       └── security.md     # Security requirements
  ```
  "All `.md` files are discovered recursively, so you can organize rules into subdirectories like `frontend/` or `backend/`". "Rules without `paths` frontmatter are loaded at launch with the same priority as `.claude/CLAUDE.md`." — [memory](https://code.claude.com/docs/en/memory)
- Path-scoped example:
  ```markdown
  ---
  paths:
    - "src/api/**/*.ts"
  ---

  # API Development Rules

  - All API endpoints must include input validation
  - Use the standard error response format
  - Include OpenAPI documentation comments
  ```
  "Path-scoped rules trigger when Claude uses the Read, Write, or Edit tool on a file matching the pattern, not on every tool use." — [memory](https://code.claude.com/docs/en/memory)
- Glob table: `**/*.ts` all TS files any directory; `src/**/*` all files under `src/`; `*.md` markdown in project root; `src/components/*.tsx`. Brace expansion allowed (`"src/**/*.{ts,tsx}"`), bounded to "one budget of 1,000 expanded patterns and 4 MiB" per rule (fix for OOM in v2.1.217). `[` is a bracket expression; escape as `\[`. — [memory](https://code.claude.com/docs/en/memory)
- Frontmatter reference: "`paths` is the only field Claude Code reads from a rule; any other field is ignored without an error. Claude Code removes the frontmatter before loading the rule into context." `paths` "Accepts a YAML list or a comma-separated string". "If the YAML between the markers doesn't parse, Claude Code ignores the frontmatter and loads the rule as if it had no `paths`. Run `claude --debug` to see the parse error." — [memory](https://code.claude.com/docs/en/memory)
- Symlinks: "`.claude/rules/` directory supports symlinks… A symlink whose target is outside your working directory [is treated] like an external import… after [approval] only the ones without a `paths` field load." Example: `ln -s ~/shared-claude-rules .claude/rules/shared`. Network paths are not followed. — [memory](https://code.claude.com/docs/en/memory)
- User-level rules: `~/.claude/rules/` "apply to every project on your machine… Claude Code loads user-level rules before project rules… Neither set overrides the other". — [memory](https://code.claude.com/docs/en/memory)
- Setting sources: "Project rules are skipped if you exclude `project` from `--setting-sources`. Before v2.1.211, rules that load on demand… loaded even when `project` was excluded." — [memory](https://code.claude.com/docs/en/memory)
- Rules vs skills: "Rules load into context every session or when matching files are opened. For task-specific instructions that don't need to be in context all the time, use skills instead". — [memory](https://code.claude.com/docs/en/memory)
- Steering guide: "Constraints tied to certain files → path-scoped rules… Unscoped rules → treat like CLAUDE.md. They always load and always cost tokens." Example rule: "migrations are append-only". — [Steering Claude Code](https://claude.com/blog/steering-claude-code-skills-hooks-rules-subagents-and-more)

**Reported parsing problems (community)**
- Issue #17204 (opened Jan 9 2026, closed "not planned", no maintainer reply): on WSL2 the reporter found `globs: "**/*.cs"` and unquoted `paths: **/*.cs` loaded, while quoted `paths: "**/*.cs"` and the YAML-list form did not; silent failure. The report is internally inconsistent (table vs prose). — [anthropics/claude-code#17204](https://github.com/anthropics/claude-code/issues/17204)
- Issue #22170 (Claude Code 2.1.27, macOS): a rule with `paths` frontmatter was skipped in a Go project; removing frontmatter and restarting made it load. — [anthropics/claude-code#22170 (search result)](https://github.com/anthropics/claude-code/issues/22170)

**Real Swift rules (verbatim excerpts from tomada1114/ios-template, Swift 6 / SwiftUI / SwiftData / XcodeGen template)**
- `.claude/rules/swift.md` frontmatter and key lines:
  ```markdown
  ---
  paths:
    - "Packages/**/*.swift"
    - "App/**/*.swift"
  ---

  ## Design

  - One logical concern per file. SwiftLint enforces its default limits under `strict: true`
    (warnings fail): a file over 400 lines (`file_length`), a function body over 50 lines
    (`function_body_length`), or more than 5 parameters (`function_parameter_count`) fails
    `just lint` — group related parameters in a struct long before that
  - Value types first: reach for `struct`/`enum`; use `class` only for identity or reference semantics
  - `MyAppCore` must never import SwiftUI, UIKit, AppKit, Cocoa, SwiftData, CoreData,
    CloudKit, UserNotifications, CoreLocation, Photos, PhotosUI, StoreKit, or WidgetKit —
    it stays free of UI, persistence, and OS-integration frameworks (enforced by
    `.swiftlint.yml`'s `no_ui_import_in_core` and `ArchitectureBoundaryTests`).
  ...
  - `MyAppUI` and `MyAppPlatform` are siblings and never import each other; `App/` is the
    composition root that hands a `MyAppPlatform` adapter, as a port, to Core's `AppModel`
  ...
  ## Concurrency

  - Swift 6 language mode is on: data-race safety errors are non-negotiable
  - UI-facing state is `@MainActor` (`TodoListViewModel`); keep Core types `Sendable` where
    they cross actors
  ...
  - No `@unchecked Sendable` without a comment proving the invariant it papers over
  ```
  Also sections "Two platforms at compile time" (iOS-only API goes inside `#if os(iOS)`), "Persistence" (`@Model`/`ModelContainer` only in `Sources/MyAppPlatform/Persistence/`), "Access Control" (`package` instead of `@testable import`), "Error Handling" ("NEVER `try!` or force-unwrap (`!`) in production code"), "Logging" ("`os.Logger` is the only logging facility. NEVER `print`… Enforced by `.swiftlint.yml`'s `no_print_in_sources`"). — [ios-template .claude/rules/swift.md](https://github.com/tomada1114/ios-template/blob/main/.claude/rules/swift.md)
- `.claude/rules/project.md` frontmatter and gates:
  ```markdown
  ---
  paths:
    - "project.yml"
    - "Packages/**/Package.swift"
    - "Packages/**/Package.resolved"
    - "mise.toml"
    - ".swiftlint.yml"
    - ".swiftformat"
    - "scripts/coverage.sh"
    - "Config/*.xcconfig"
  ---
  ## Dependency Policy
  - The template ships with ZERO package dependencies — keep it that way unless the app truly needs one
  ...
  ## Gates
  - NEVER lower a coverage floor (currently 80% of lines and 75% of functions on MyAppCore)
  - NEVER remove SwiftLint rules without explicit user approval
  ## Project Generation
  - `project.yml` is the source of truth; `MyApp.xcodeproj` is generated and gitignored —
    never hand-edit or commit it
  ```
  — [ios-template .claude/rules/project.md](https://github.com/tomada1114/ios-template/blob/main/.claude/rules/project.md)
- `.claude/rules/testing.md` (`paths: ["Packages/**/Tests/**", "LaunchUITests/**"]`): "Swift Testing only (`@Test`, `#expect`, `#require`, `@Suite`); XCTest is reserved for the XCUITest launch target"; "TDD is required"; "Fakes, not mocks"; "No `sleep` or timing-based assertion in a unit test"; "NEVER weaken an assertion to make a test pass — fix the code". — [ios-template .claude/rules/testing.md](https://github.com/tomada1114/ios-template/blob/main/.claude/rules/testing.md)
- `.claude/rules/docs.md` (`paths: ["docs/**/*.md","README.md","CONTRIBUTING.md","CHANGELOG.md"]`). — [ios-template .claude/rules/docs.md](https://github.com/tomada1114/ios-template/blob/main/.claude/rules/docs.md)
- The rationale recorded in the issue that introduced these rules (Sep 30 2026): "without them it re-derives 'where does a test go' and 'may Core import SwiftData' every time." — [tomada1114/ios-template#5](https://github.com/tomada1114/ios-template/issues/5)
- The AGENTS.md "Rules" table is the index Claude sees at launch ("The files under `.claude/rules/` load by path: each applies while you touch a file matching its `paths:` globs."). — [ios-template AGENTS.md](https://github.com/tomada1114/ios-template/blob/main/AGENTS.md)

**Composed tvOS/UIKit/SwiftUI rule files (derived from the syntax above; untested)**
```markdown
<!-- .claude/rules/features-layering.md -->
---
paths:
  - "Features/**/*.swift"
---
# Feature-module boundaries
- Files under `Features/` must not `import Networking`, `import Persistence`, or name `URLSession`/`ModelContext` directly. Depend on a `Core`-declared protocol (port) and receive the adapter through the composition root in `App/`.
- These rules are enforced by `.swiftlint.yml` `no_infra_import_in_features` and `ArchitectureBoundaryTests`; if a change needs an exception, stop and ask instead of adding `// swiftlint:disable`.
```
```markdown
<!-- .claude/rules/tvos.md -->
---
paths:
  - "**/tvOS/**/*.swift"
  - "**/*+tvOS.swift"
---
# tvOS focus and input
- Every interactive view must be reachable with the Siri Remote: verify `focusable`/`@FocusState` paths and `.focusSection()` grouping; never rely on tap gestures.
- Use `#if os(tvOS)` for tvOS-only APIs; shared files must compile for iOS and tvOS (`xcodebuild -destination 'platform=tvOS Simulator,name=Apple TV'`).
```
(These two blocks are my composition; the glob and frontmatter syntax is from [memory](https://code.claude.com/docs/en/memory). The import-ban-plus-double-enforcement pattern is from [ios-template](https://github.com/tomada1114/ios-template/blob/main/.claude/rules/swift.md).)

### Inferences
- Layering rules in `.claude/rules/` should *describe* the boundary and *name the gate* that enforces it (SwiftLint custom rule + architecture test), so Claude knows both the rule and that circumventing it will fail CI. The ios-template rule files do exactly this.
- Given the reported parsing issues (#17204, #22170), a playbook should include a verification step: run `/context` (or `claude --debug`) after touching a matching file to confirm the rule loaded, and prefer the documented quoted-YAML-list form which is what the docs show.
- Because `paths` matching fires on Read/Write/Edit, a rule about `*.pbxproj` would load only when Claude touches that file — too late to prevent the edit; use a PreToolUse hook or `Edit(**/*.pbxproj)` deny rule for prevention.

### Gaps
- No official statement on whether `paths` globs match against project-relative or absolute paths beyond the examples; the docs' examples are project-relative.
- The docs do not state a per-rule length recommendation distinct from CLAUDE.md's "under 200 lines"; the instruction-file length warning applies to "Each CLAUDE.md, rules file, and `@path` import" individually.

---

## Key question 3: Hooks — events, matchers, stdin JSON, exit codes, JSON output, Swift examples, newer hook types

### Takeaway
Hooks are the deterministic layer: 33 events as of the current docs (including `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, `PermissionDenied`, `UserPromptSubmit`, `Stop`, `SubagentStart`/`SubagentStop`, `SessionStart`/`SessionEnd`, `PreCompact`/`PostCompact`, `InstructionsLoaded`, `FileChanged`, `WorktreeCreate`…), five handler types (`command`, `http`, `mcp_tool`, `prompt`, `agent`), exit code 2 = block with stderr fed to Claude, exit 1 = non-blocking, and structured JSON output (`permissionDecision`, `updatedInput`, `additionalContext`, `decision: "block"`). For Swift: run swiftformat/SwiftLint on the edited file in `PostToolUse` (exit 2 on failure so Claude sees stderr), block `.pbxproj`/lockfile writes in `PreToolUse`, gate `Stop` with tests via a `command`/`agent` hook, and inject build status via `SessionStart` stdout.

### Cited Findings

**Events (verbatim list of 33, grouped as the docs group them)**
- Per session: `SessionStart`, `SessionEnd`, `Setup` (only with `--init-only`, or `--init`/`--maintenance` in `-p` mode). Per turn: `UserPromptSubmit`, `UserPromptExpansion`, `Stop`, `StopFailure`. Per tool call: `PreToolUse`, `PermissionRequest`, `PermissionDenied`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`. Subagents and tasks: `SubagentStart`, `SubagentStop`, `TaskCreated`, `TaskCompleted`, `TeammateIdle`. Config and environment: `InstructionsLoaded`, `ConfigChange`, `CwdChanged`, `DirectoryAdded`, `FileChanged`, `WorktreeCreate`, `WorktreeRemove`. Compaction and models: `PreCompact`, `PostCompact`, `PreModelSwitch`, `PostModelSwitch`. Other: `Notification`, `MessageDisplay`, `Elicitation`, `ElicitationResult`. — [hooks reference](https://code.claude.com/docs/en/hooks)
- When each was introduced: "1.0.41 — Split Stop hook triggering into Stop and SubagentStop"; "1.0.48 — Added a PreCompact hook"; "1.0.54 — Added UserPromptSubmit hook and the current working directory to hook inputs"; "1.0.62 — Added SessionStart hook"; "1.0.85 — Introduced SessionEnd hook"; "2.0.45 — Added `PermissionRequest` hook to automatically approve or deny tool permission requests with custom logic"; "2.1.0 — Added support for prompt and agent hook types from plugins"; "2.1.69 — Added `InstructionsLoaded` hook event"; "2.1.105 — Added PreCompact hook support: hooks can now block compaction by exiting with code 2 or returning `{"decision":"block"}`"; "2.1.163 — Stop and SubagentStop hooks can now return `hookSpecificOutput.additionalContext`". — [CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)

**Configuration structure (verbatim)**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "if": "Bash(rm *)",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/block-rm.sh",
            "args": []
          }
        ]
      }
    ]
  }
}
```
"Hooks live in JSON settings with three levels: event → matcher group → handler(s)." Locations: `~/.claude/settings.json`, `.claude/settings.json`, `.claude/settings.local.json`, managed policy settings, plugin `hooks/hooks.json`, skill frontmatter, subagent frontmatter; "Hooks from different levels merge." — [hooks reference](https://code.claude.com/docs/en/hooks)
- Matcher syntax: "`"*"`, `""`, or omitted: match all. Only letters, digits, `_`, `-`, spaces, `,`, `|`: exact name or list (`Edit|Write`). Any other character: JavaScript regex, unanchored (`^Notebook`, `mcp__memory__.*`)." Tool events match `tool_name`; `SessionStart` matches `source`; `ConfigChange` matches the config source; `Notification` matches `notification_type`; `PreCompact` matches `manual`/`auto`; `SessionEnd` matches `reason`. — [hooks reference](https://code.claude.com/docs/en/hooks)
- Handler types: "`command`: shell command; reads JSON on stdin. `http`: POSTs the JSON input to a URL. `mcp_tool`: calls a configured MCP server tool. `prompt`: single-turn model evaluation; uses `$ARGUMENTS` for the input JSON; default timeout 30s. `agent`: spawns a subagent that can use Read, Grep, Glob; experimental; default timeout 60s." Common fields: `type`, `if` (permission-rule syntax, tool events only), `timeout` (default 600s for command/http/mcp_tool), `statusMessage`, `once` (skill frontmatter only). Command-specific: `args` (exec form, no shell), `async`, `asyncRewake` (wakes Claude on exit 2), `shell` (`bash`/`powershell`). Placeholders `${CLAUDE_PROJECT_DIR}`, `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PLUGIN_DATA}`. — [hooks reference](https://code.claude.com/docs/en/hooks)
- `if` field semantics (verbatim table): `Bash(git *)` runs for `git push`, for `npm test && git push` ("each subcommand is checked"), for `echo $(git log)`; not for `echo $(date)`. "When Claude Code can't determine which commands the Bash input runs, it runs your hook regardless of the pattern… Because the filter is best-effort, use the permission system rather than a hook to enforce a hard allow or deny." `if` only works on `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, `PermissionDenied`. — [hooks guide](https://code.claude.com/docs/en/hooks-guide)

**Stdin payload (verbatim)**
- Common fields on every event: `session_id`, `prompt_id`, `transcript_path`, `cwd`, `scratchpad_dir` (v2.1.257+), `permission_mode`, `effort`, `hook_event_name`; subagent calls add `agent_id` and `agent_type`. — [hooks reference](https://code.claude.com/docs/en/hooks)
- `PreToolUse` input:
  ```json
  {
    "session_id": "abc123",
    "cwd": "/home/user/my-project",
    "permission_mode": "default",
    "hook_event_name": "PreToolUse",
    "tool_name": "Bash",
    "tool_input": { "command": "npm test", "timeout": 120000 },
    "tool_use_id": "toolu_01ABC123..."
  }
  ```
- `PostToolUse` input adds `tool_response` (e.g. `{"filePath": "/path/to/file.txt", "type": "create"}`) and `duration_ms`. `PostToolUseFailure` adds `error`, `is_interrupt`. — [hooks reference](https://code.claude.com/docs/en/hooks)
- `Stop` input: `stop_hook_active`, `last_assistant_message`, `background_tasks`, `session_crons`. "The `stop_hook_active` field is `true` when Claude Code is already continuing as a result of a stop hook. Check this value… to avoid blocking on a condition that will never resolve." "Claude Code applies an 8-consecutive-continuation cap… To raise the cap, set `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`." `SubagentStop` adds `agent_id`, `agent_type`, `agent_transcript_path`. — [hooks reference](https://code.claude.com/docs/en/hooks)
- `SessionStart`: `source` is `startup`, `resume`, `clear`, `compact`, or `fork` (v2.1.214+), optional `model`; on resume (v2.1.251+) also `seconds_since_last_response`, `context_tokens`, `prompt_cache_likely_expired`, `estimated_cache_write_usd`. Output fields: `additionalContext`, `initialUserMessage`, `sessionTitle`, `watchPaths`, `reloadSkills`. — [hooks reference](https://code.claude.com/docs/en/hooks)
- `UserPromptSubmit`: input `prompt`, optional `session_title`; output `decision: "block"` + `reason`, `hookSpecificOutput.additionalContext`, `sessionTitle`, `suppressOriginalPrompt`; default timeout 30 s. — [hooks reference](https://code.claude.com/docs/en/hooks)
- `PreCompact`: `trigger` (`manual`|`auto`), `custom_instructions`; exit 2 or `{"decision":"block"}` blocks compaction. `PostCompact`: `trigger`, `compact_summary`; no decision control. — [hooks reference](https://code.claude.com/docs/en/hooks)
- `SessionEnd`: `reason` ∈ `clear`, `resume`, `logout`, `prompt_input_exit`, `other`; no decision control; default 1.5 s budget, raised by per-hook `timeout` up to 60 s or `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS`. — [hooks reference](https://code.claude.com/docs/en/hooks)
- `Notification`: `message`, `title`, `notification_type` ∈ `permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_*`, `agent_needs_input`, `agent_completed`, `quota_auto_resume_*`; cannot block. — [hooks reference](https://code.claude.com/docs/en/hooks)
- `PermissionRequest`: input `tool_name`, `tool_input`, optional `permission_suggestions`; output `hookSpecificOutput.decision` with `behavior` `allow`/`deny`, `updatedInput`/`updatedPermissions` (allow), `message`/`interrupt` (deny). `PermissionDenied` (auto mode only): output `retry: true`. — [hooks reference](https://code.claude.com/docs/en/hooks)
- `InstructionsLoaded`: `file_path`, `memory_type`, `load_reason`. `FileChanged`: `file_path`, `event` (`change`/`add`/`unlink`); matcher is a `|`-separated literal filename watch list. `TaskCompleted`: `task_id`, `task_subject`…; exit 2 blocks completion. — [hooks reference](https://code.claude.com/docs/en/hooks)

**Exit codes and JSON output (verbatim)**
- "0: success. Stdout is parsed as JSON if it starts with `{` and ends with `}`; otherwise it's plain text. Plain-text stdout becomes context only for `UserPromptSubmit`, `UserPromptExpansion`, `SessionStart`, and `PostModelSwitch`. 2: blocking error. Stderr is the reason… blocks a `PreToolUse` call, rejects a prompt, prevents `Stop`, and so on. It does not block on `PostToolUse`, `Notification`, `SessionStart`, and similar events. Other: non-blocking error. The action proceeds, and the transcript shows a notice. The page warns that exit 1 does not block, so enforcement hooks should use `exit 2`." — [hooks reference](https://code.claude.com/docs/en/hooks)
- Universal output fields: `continue` (default true; `false` stops Claude entirely), `stopReason`, `suppressOutput` (no effect), `systemMessage`, `terminalSequence`. Decision patterns:
  ```json
  { "decision": "block", "reason": "Test suite must pass before proceeding" }
  ```
  ```json
  {
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "Database writes are not allowed"
    }
  }
  ```
  "PreToolUse: `permissionDecision` (`allow`/`deny`/`ask`/`defer`), `permissionDecisionReason`, `updatedInput`. PermissionRequest: `decision.behavior`… PostToolUse: `updatedToolOutput`… Top-level `decision`: used by UserPromptSubmit, PostToolUse, Stop, SubagentStop, ConfigChange, PreCompact". `additionalContext`, `systemMessage`, `initialUserMessage` capped at 10,000 chars. — [hooks reference](https://code.claude.com/docs/en/hooks)
- PostToolUse `decision: "block"` "adds `reason` next to the tool result. Claude still sees the original output." Output example with `updatedToolOutput` (replaces what Claude sees; "The tool has already run by the time the hook fires"). — [hooks reference](https://code.claude.com/docs/en/hooks)
- Stop output: "`decision` (`"block"` prevents stopping), `reason` (required when blocking), and `hookSpecificOutput.additionalContext`. Exiting 2 routes stderr the same way as `reason`." — [hooks reference](https://code.claude.com/docs/en/hooks)
- "v2.1.214… exit 2 with invalid JSON now blocks. v2.1.248: unparseable stdout on exit 0 is a non-blocking error rather than plain text." — [hooks reference](https://code.claude.com/docs/en/hooks)

**Official examples (verbatim)**
- Format on edit:
  ```json
  {
    "hooks": {
      "PostToolUse": [
        {
          "matcher": "Edit|Write",
          "hooks": [
            {
              "type": "command",
              "command": "jq -r '.tool_input.file_path' | xargs npx prettier --write"
            }
          ]
        }
      ]
    }
  }
  ```
  "To reformat a specific file however it changes, including when a `Bash` command rewrites it, use a FileChanged hook instead." — [hooks guide](https://code.claude.com/docs/en/hooks-guide)
- Block edits to protected files — `.claude/hooks/protect-files.sh`:
  ```bash
  #!/bin/bash
  # protect-files.sh

  INPUT=$(cat)
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

  # Normalize Windows backslash separators so the patterns below match
  FILE_PATH="${FILE_PATH//\\//}"

  PROTECTED_PATTERNS=(".env" "package-lock.json" ".git/")

  for pattern in "${PROTECTED_PATTERNS[@]}"; do
    if [[ "$FILE_PATH" == *"$pattern"* ]]; then
      echo "Blocked: $FILE_PATH matches protected pattern '$pattern'" >&2
      exit 2
    fi
  done

  exit 0
  ```
  registered as:
  ```json
  {
    "hooks": {
      "PreToolUse": [
        {
          "matcher": "Edit|Write",
          "hooks": [
            {
              "type": "command",
              "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/protect-files.sh"
            }
          ]
        }
      ]
    }
  }
  ```
  "Hook scripts must be executable" (`chmod +x`). — [hooks guide](https://code.claude.com/docs/en/hooks-guide)
- Re-inject context after compaction:
  ```json
  {
    "hooks": {
      "SessionStart": [
        {
          "matcher": "compact",
          "hooks": [
            {
              "type": "command",
              "command": "echo 'Reminder: use Bun, not npm. Run bun test before committing. Current sprint: auth refactor.'"
            }
          ]
        }
      ]
    }
  }
  ```
  "You can replace the `echo` with any command that produces dynamic output, like `git log --oneline -5`." — [hooks guide](https://code.claude.com/docs/en/hooks-guide)
- `SessionStart` + `CwdChanged` writing `direnv export bash > "$CLAUDE_ENV_FILE"` ("which Claude Code runs as a script preamble before each Bash command"). — [hooks guide](https://code.claude.com/docs/en/hooks-guide)
- Audit config changes with `ConfigChange` (matcher values `user_settings`, `project_settings`, `local_settings`, `policy_settings`, `skills`; "To block a change from taking effect, exit with code 2 or return `{"decision": "block"}`"). — [hooks guide](https://code.claude.com/docs/en/hooks-guide)
- Auto-approve `ExitPlanMode` via `PermissionRequest`: `echo '{"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": {"behavior": "allow"}}}'`; "Keep the matcher as narrow as possible. Matching on `.*` or leaving the matcher empty would auto-approve every tool permission prompt". — [hooks guide](https://code.claude.com/docs/en/hooks-guide)
- Test gate script (TaskCompleted, same shape works for Stop):
  ```bash
  #!/bin/bash
  INPUT=$(cat)
  TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject')

  # Run the test suite
  if ! npm test 2>&1; then
    echo "Tests not passing. Fix failing tests before completing: $TASK_SUBJECT" >&2
    exit 2
  fi

  exit 0
  ```
  — [hooks reference](https://code.claude.com/docs/en/hooks)
- Team settings example wiring a Bash guard: `"command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/block-rm.sh"` under `PreToolUse` matcher `Bash`. — [settings-example](https://code.claude.com/docs/en/settings-example)

**Prompt-based and agent-based hooks (newer types)**
- Supported on `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionDenied`, `PostToolBatch`, `Stop`, `SubagentStop`, `TaskCreated`, `TaskCompleted`, `TeammateIdle`, `UserPromptSubmit`, `UserPromptExpansion`; `PermissionRequest` supports prompt but not agent; `SessionStart`/`Setup` support only `command` and `mcp_tool`. — [hooks reference](https://code.claude.com/docs/en/hooks)
- Prompt hook config fields: `type: "prompt"`, `prompt` (with `$ARGUMENTS`), `model`, `timeout` (default 30), `continueOnBlock`. Response schema `{"ok": true|false, "reason": "...", "impossible": true|false}`. On `Stop`, `ok: false` feeds `reason` back as the next instruction unless `impossible: true`. — [hooks reference](https://code.claude.com/docs/en/hooks)
  ```json
  {
    "hooks": {
      "Stop": [
        {
          "hooks": [
            {
              "type": "prompt",
              "prompt": "Evaluate if Claude should stop: $ARGUMENTS. Check if all tasks are complete."
            }
          ]
        }
      ]
    }
  }
  ```
- Agent hook: "spawns a subagent that can read files, search code… After up to 50 turns, the subagent returns a structured `{ "ok": true/false }` decision"; "Agent hooks are experimental"; default timeout 60 s:
  ```json
  {
    "hooks": {
      "Stop": [
        {
          "hooks": [
            {
              "type": "agent",
              "prompt": "Verify that all unit tests pass. Run the test suite and check the results. $ARGUMENTS",
              "timeout": 120
            }
          ]
        }
      ]
    }
  }
  ```
  — [hooks reference](https://code.claude.com/docs/en/hooks), [hooks guide](https://code.claude.com/docs/en/hooks-guide)
- Async hooks: `"async": true` on command hooks; "Async hooks can't block or control Claude's behavior"; output delivered next turn; `asyncRewake` wakes Claude on exit 2. HTTP hooks: `url`, `headers` with `$VAR`, `allowedEnvVars`; "HTTP status codes alone can't block actions." MCP tool hooks: `server`, `tool`, `input` with `${tool_input.file_path}` substitution. — [hooks reference](https://code.claude.com/docs/en/hooks)
- Hooks in frontmatter: "skill hooks persist for the session unless `once: true`; subagent hooks run only while the subagent runs, and `Stop` is converted to `SubagentStop`." "v2.1.218: frontmatter hooks in project subagents require workspace trust." — [hooks reference](https://code.claude.com/docs/en/hooks)
- Trust/security: "Interactive session: Claude Code holds back hooks from every settings file… until you accept the workspace trust dialog. `-p` or SDK session: Claude Code never shows the dialog and treats the folder as trusted, so hooks committed in a repository's `.claude/settings.json` run in a folder you've never trusted." Best practices: quote variables, block `..`, use `${CLAUDE_PROJECT_DIR}` absolute paths, skip `.env`/`.git/`/keys. `"disableAllHooks": true` disables; managed `allowManagedHooksOnly` restricts which hooks run (v2.1.229 also disables `command`-source plugins). — [hooks reference](https://code.claude.com/docs/en/hooks), [managed-settings](https://code.claude.com/docs/en/managed-settings)
- `/hooks` "View hook configurations"; debugging via `claude --debug`. — [commands](https://code.claude.com/docs/en/commands), [hooks guide](https://code.claude.com/docs/en/hooks-guide)
- Best practices page: "Use hooks for actions that must happen every time with zero exceptions… Unlike CLAUDE.md instructions which are advisory, hooks are deterministic". "Claude can write hooks for you. Try prompts like 'Write a hook that runs eslint after every file edit' or 'Write a hook that blocks writes to the migrations folder.'" — [best-practices](https://code.claude.com/docs/en/best-practices)

**Real Swift PostToolUse formatter (verbatim, tomada1114/ios-template `scripts/format-edited-file.sh`)**
```bash
#!/usr/bin/env bash
# Format the one Swift file a Claude Code Edit/Write/MultiEdit just touched.
# Meant to be registered as a Claude Code PostToolUse hook in a personal settings file
# (~/.claude/settings.json or the gitignored .claude/settings.local.json; see AGENTS.md):
#
#   <hook JSON on stdin> | scripts/format-edited-file.sh [--root DIR]
#
# Reads tool_input.file_path out of the hook's JSON payload and runs
# `swiftformat <that file>` from the root, so .swiftformat applies. Nothing else in
# the tree is touched. It exits 0 without running anything when the payload names
# no file_path, the path does not end in .swift, the file no longer exists, or the
# file lies outside the root. ...
#
# Exit codes: 0 formatted or nothing to do; 2 on failure, because Claude Code feeds
# a PostToolUse hook's stderr back to the agent only on exit 2 — the failure is
# reported to whoever made the edit instead of being silenced.
set -euo pipefail
...
payload=$(cat)
file=$(printf '%s\n' "${payload}" | tr -d '\n' |
    sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"\\]*\(\\\/[^"\\]*\)*\)".*/\1/p' |
    sed 's#\\/#/#g')

case "${file}" in
    *.swift) ;;
    *) exit 0 ;;
esac
[ -f "${file}" ] || exit 0

# Resolve symlinks and relative segments before the inside-the-root comparison.
dir=$(cd "$(dirname "${file}")" && pwd -P)
resolved="${dir}/$(basename "${file}")"
case "${resolved}" in
    "${ROOT}"/*) ;;
    *) exit 0 ;;
esac

if ! output=$(cd "${ROOT}" && swiftformat "${resolved}" 2>&1); then
    fail ERR_FORMAT_FAILED "swiftformat could not format the edited file" \
        "swiftformat exits 0 on ${resolved#"${ROOT}"/}" \
        "$(printf '%s' "${output}" | tail -n 5 | tr '\n' ' ')" \
        "fix the syntax error, then run: mise exec -- swiftformat ${resolved#"${ROOT}"/}"
fi
exit 0
```
Registration (from the issue that added it): `"PostToolUse": [{ "matcher": "Edit|Write|MultiEdit", "command": "cd \"$CLAUDE_PROJECT_DIR\" && mise exec -- scripts/format-edited-file.sh" }]` plus `"Bash(scripts/format-edited-file.sh:*)"` in `permissions.allow`; "Claude Code feeds a PostToolUse hook's stderr back to the agent only on exit 2" and "settings.json is JSON — no comments." — [ios-template scripts/format-edited-file.sh](https://github.com/tomada1114/ios-template/blob/main/scripts/format-edited-file.sh), [ios-template#5](https://github.com/tomada1114/ios-template/issues/5)

- Community iOS guide hooks (summary of page content): `SessionStart` runs `session-start.sh` reporting Swift/Xcode versions and whether a simulator is booted; `PostToolUse` (`Write|Edit`) pipes `jq` file path to `swiftlint lint` for `.swift`; `PreToolUse` (`Edit|Write`) Python one-liner exits 2 when the path contains `.env` or `Secrets.swift`; a `file-protection.sh` blocks `GoogleService-Info.plist`, `.git/`, `Podfile.lock`; a `post-swift-edit.sh` runs SwiftLint plus swift-format. — [keskinonur/claude-code-ios-dev-guide](https://github.com/keskinonur/claude-code-ios-dev-guide)
- Community pitfalls noted in search: one SwiftLint hook example "sends errors to `/dev/null` and never exits 2, so Claude would not see violations"; another runs `swiftlint --config .swiftlint.yml --fix` with no file argument (whole tree per edit). — [search summary of community posts](https://blog.vincentqiao.com/en/posts/claude-code-settings-hooks/)
- johnrogers/claude-swift-engineering plugin ships `UserPromptSubmit` hooks `skill-forced-eval-hook.sh` and `agent-forced-eval-hook.sh` ("skill/agent evaluation hooks for better workflow discipline"), pins "Swift 6.2 with strict concurrency", and installs via `/plugin marketplace add https://github.com/johnrogers/claude-swift-engineering` then `/plugin install swift-engineering`. — [johnrogers/claude-swift-engineering](https://github.com/johnrogers/claude-swift-engineering)

**Composed Swift/tvOS hook set (derived from documented syntax; untested)**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/protect-project-files.sh" }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "if": "Bash(git push *)", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/block-force-push.sh" },
          { "type": "command", "if": "Bash(rm *)", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/block-rm-rf.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/lint-swift-file.sh", "timeout": 120 }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/session-status.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/stop-gate.sh", "timeout": 900 }
        ]
      }
    ]
  }
}
```
```bash
#!/bin/bash
# .claude/hooks/protect-project-files.sh  (PreToolUse; exit 2 = block)
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
case "$FILE_PATH" in
  *.pbxproj|*.xcworkspacedata|*/Podfile.lock|*/Package.resolved|*.xcconfig|*.entitlements|*.mobileprovision)
    echo "Blocked: $FILE_PATH is a generated/locked project file. Edit project.yml (XcodeGen) or ask a human." >&2
    exit 2 ;;
esac
exit 0
```
```bash
#!/bin/bash
# .claude/hooks/lint-swift-file.sh  (PostToolUse; exit 2 so stderr reaches Claude)
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ "$FILE" == *.swift && -f "$FILE" ]] || exit 0
cd "$CLAUDE_PROJECT_DIR" || exit 0
swiftformat "$FILE" --quiet || { echo "swiftformat failed on $FILE" >&2; exit 2; }
if ! swiftlint lint --quiet --strict "$FILE" >&2; then
  echo "SwiftLint violations in $FILE (see above). Fix them; do not add swiftlint:disable." >&2
  exit 2
fi
exit 0
```
```bash
#!/bin/bash
# .claude/hooks/stop-gate.sh  (Stop; blocks until unit tests pass; respects the loop guard)
INPUT=$(cat)
[ "$(echo "$INPUT" | jq -r '.stop_hook_active')" = "true" ] && exit 0
cd "$CLAUDE_PROJECT_DIR" || exit 0
if ! xcodebuild test -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -n 40 >&2; then
  echo "Unit tests failed; fix them before finishing." >&2
  exit 2
fi
exit 0
```
```bash
#!/bin/bash
# .claude/hooks/session-status.sh  (SessionStart; plain stdout becomes context)
echo "Xcode: $(xcodebuild -version | head -1); Swift: $(swift --version 2>&1 | head -1)"
echo "Booted simulators: $(xcrun simctl list devices booted | grep -c '(Booted)')"
echo "Last CI result on this branch: $(gh run list --branch "$(git branch --show-current)" --limit 1 --json conclusion -q '.[0].conclusion' 2>/dev/null || echo unknown)"
```
(Syntax sources: hook config/exit-code/stdin fields from [hooks reference](https://code.claude.com/docs/en/hooks); `protect-files.sh` shape and `$CLAUDE_PROJECT_DIR` quoting from [hooks guide](https://code.claude.com/docs/en/hooks-guide); `stop_hook_active` guard from [hooks reference](https://code.claude.com/docs/en/hooks); the single-file swiftformat+exit-2 pattern from [ios-template](https://github.com/tomada1114/ios-template/blob/main/scripts/format-edited-file.sh). SwiftLint's README does not document `swiftlint lint <path>` explicitly — it documents `--config`, `--fix`, `--strict` and `--use-script-input-files` — so verify the single-file invocation locally; see KQ8.)

### Inferences
- The combination "PreToolUse deny for generated files" + "PostToolUse single-file format/lint with exit 2" + "Stop gate with `stop_hook_active` guard" covers the three regression vectors the question lists (bad project-file edits, style drift, shipping with red tests). A `Stop` gate running full `xcodebuild test` is slow; the docs' `agent` hook or a narrower unit-test-only target keeps it tolerable, and the 8-continuation cap prevents infinite loops.
- Because Bash-pattern `if`/deny rules do not match `/bin/rm` or `bash -c 'rm …'`, use the sandbox for real enforcement (KQ4), and treat hook/deny rules as "catches what Claude normally writes".

### Gaps
- No official Swift/Xcode-specific hook example exists in Anthropic docs; the Swift-specific examples above are community (ios-template, keskinonur) or composed.
- Could not fetch samwize.com's "trailing whitespace" hook post or tatejennings.com (DNS); their exact JSON is unverified.

---

## Key question 4: Settings and permissions — layering, rule syntax, modes, `--allowedTools`, sandboxing, managed policy

### Takeaway
Settings precedence is managed → `--settings` CLI → `.claude/settings.local.json` → `.claude/settings.json` → `~/.claude/settings.json`; permission rules are `Tool` or `Tool(specifier)` with deny > ask > allow; Bash rules match the command text Claude writes (prefix `*`, `:*`), path rules use gitignore globs with `//` absolute, `~/`, `/` settings-relative and bare cwd-relative prefixes; MCP tools are `mcp__server__tool`. Deny rules apply in every mode including `bypassPermissions`. For governance, managed-settings.json (`/Library/Application Support/ClaudeCode/`, `/etc/claude-code/`, `C:\Program Files\ClaudeCode\`) can set `allowManagedPermissionRulesOnly`, `disableBypassPermissionsMode`, `disableAutoMode`, `allowManagedHooksOnly`, MCP allow/deny lists, and an OS-enforced sandbox with `failIfUnavailable` and `allowUnsandboxedCommands: false`.

### Cited Findings

**Files and precedence**
- Precedence highest first: "1. Managed settings — managed-settings.json, MDM, or the claude.ai console (Your organization); 2. Command line — `claude --settings` (You, this session); 3. Project local — `.claude/settings.local.json` (You, this project); 4. Shared project — `.claude/settings.json` (Everyone in the project); 5. User — `~/.claude/settings.json` (You, every project)." — [settings](https://code.claude.com/docs/en/settings)
- Managed paths: macOS `/Library/Application Support/ClaudeCode/managed-settings.json`, Linux/WSL `/etc/claude-code/managed-settings.json`, Windows `C:\Program Files\ClaudeCode\managed-settings.json` (legacy `C:\ProgramData\…` no longer read); optional `managed-settings.d/` merged alphabetically; macOS profile domain `com.anthropic.claudecode`; Windows `HKLM\SOFTWARE\Policies\ClaudeCode` `Settings` REG_SZ; server-managed settings from the claude.ai console "Fetched at startup and polled hourly". — [managed-settings](https://code.claude.com/docs/en/managed-settings)
- Managed example (verbatim):
  ```json
  {
    "permissions": {
      "deny": [
        "Read(./.env)",
        "Read(./secrets/**)"
      ],
      "disableBypassPermissionsMode": "disable"
    },
    "allowManagedPermissionRulesOnly": true
  }
  ```
  "makes Claude Code ignore permission rules from user, project, and local files and from `--allowedTools`". — [managed-settings](https://code.claude.com/docs/en/managed-settings)
- Managed-only keys (verbatim table excerpts): `allowManagedHooksOnly` ("restricts which hooks run"), `allowManagedMcpServersOnly`, `allowManagedPermissionRulesOnly`, `disableCommandPluginSources`, `disableSideloadFlags` ("Reject the `--plugin-dir`, `--plugin-url`, `--agents`, and `--mcp-config` flags at startup"), `strictKnownMarketplaces`, `strictPluginOnlyCustomization` ("Block skills, agents, hooks, and MCP servers from user and project sources; `true` locks all four, an array names which"). Merge rules across managed sources: lists combine (`permissions.allow`, `hooks`, `sandbox.network.allowedDomains`, `deniedMcpServers`); locks take the strictest (`allowManagedHooksOnly`, `permissions.disableBypassPermissionsMode`); restriction allowlists taken whole from the highest-ranked source (`availableModels`, `allowedMcpServers`, `strictKnownMarketplaces`). — [managed-settings](https://code.claude.com/docs/en/managed-settings)
- Full organization example (verbatim) — pins login org, `availableModels`, denies `Bash(curl *)` + `.env`/secrets reads, `disableBypassPermissionsMode: "disable"`, `allowManagedPermissionRulesOnly: true`, `allowedMcpServers: [{ "serverUrl": "https://api.githubcopilot.com/*" }]`, `allowManagedMcpServersOnly: true`, `strictKnownMarketplaces`, `sandbox: { enabled, failIfUnavailable: true, allowUnsandboxedCommands: false, network: { allowedDomains: ["registry.npmjs.org","github.com"], allowManagedDomainsOnly: true } }`, `requiredMinimumVersion: "2.1.150"`, `cleanupPeriodDays: 7`, `companyAnnouncements`. — [settings-example](https://code.claude.com/docs/en/settings-example)
- Team `.claude/settings.json` example (verbatim):
  ```json
  {
    "permissions": {
      "allow": [
        "Bash(npm run *)"
      ],
      "ask": [
        "Bash(git push *)"
      ],
      "deny": [
        "Read(./.env)",
        "Read(./.env.*)",
        "Read(./secrets/**)"
      ]
    },
    "hooks": {
      "PreToolUse": [
        {
          "matcher": "Bash",
          "hooks": [
            {
              "type": "command",
              "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/block-rm.sh"
            }
          ]
        }
      ]
    },
    "extraKnownMarketplaces": { "acme-tools": { "source": { "source": "github", "repo": "acme-corp/claude-plugins" } } },
    "enabledPlugins": { "code-formatter@acme-tools": true },
    "sandbox": {
      "enabled": true,
      "filesystem": { "allowWrite": [ "/tmp/build" ] },
      "network": { "allowedDomains": [ "registry.npmjs.org", "*.example.com" ] }
    },
    "plansDirectory": "./plans"
  }
  ```
  Notes: "Allow rules wait for trust… deny and ask rules apply in every session, trusted or not." "`Read(./.env)` on its own stops the file tools and commands that name the file, such as `cat .env`, but not `grep -r` run over the directory; the `sandbox` block in this file closes that gap". — [settings-example](https://code.claude.com/docs/en/settings-example)

**Permission rule syntax**
- "Permission rules follow the format `Tool` or `Tool(specifier)`… `Bash(*)` is equivalent to `Bash`… As a deny rule, both forms remove the tool from Claude's context." — [permissions](https://code.claude.com/docs/en/permissions)
- Bash wildcard table (verbatim rows): `Bash(npm run build)` matches only exact; `Bash(npm run *)` matches `npm run build`, `npm run test --watch`, `npm run`, not `npm install`; `Bash(git log * main)`; `Bash(* --version)`; `Bash(ls *)` matches `ls -la`, `ls`, not `lsof`; `Bash(ls*)` matches `lsof`. "The `:*` suffix is an equivalent way to write a trailing wildcard, so `Bash(ls:*)` matches the same commands as `Bash(ls *)`." — [permissions](https://code.claude.com/docs/en/permissions)
- Compound commands: "a rule like `Bash(safe-cmd *)` won't give it permission to run the command `safe-cmd && other-cmd`. The recognized command separators are `&&`, `||`, `;`, `|`, `|&`, `&`, and newlines." Deny/ask rules apply when any subcommand matches, including inside `$()`. Wrappers `timeout`, `time`, `nice`, `nohup`, `stdbuf`, `command`, `builtin`, `noglob`, bare `xargs` are stripped; `mise exec`, `npx`, `docker exec` are NOT, so write `Bash(devbox run npm test)`-style full rules. — [permissions](https://code.claude.com/docs/en/permissions)
- Limits (verbatim table): `Bash(rm *)` stops `rm -rf build/` but not `/bin/rm -rf build/` or `bash -c 'rm -rf build/'`; `Bash(git push *)` stops `git push origin main` but not `git -C . push origin main` or `git -c push.default=current push origin main`. "For filesystem and network enforcement that doesn't depend on the command text, use sandboxing. To inspect the full command text… use a PreToolUse hook." — [permissions](https://code.claude.com/docs/en/permissions)
- Read-only command set runs without prompts in every mode: "`ls`, `cat`, `echo`, `pwd`, `head`, `tail`, `grep`, `find`, `wc`, `which`, `diff`, `stat`, `du`, `cd`, and read-only forms of `git`… not configurable; to require a prompt… add an `ask` or `deny` rule". Redirect targets are checked against Edit/Read rules (`tee` too, v2.1.269+). — [permissions](https://code.claude.com/docs/en/permissions)
- Path rules: `Read(.env)` or `Read(**/.env)` block any `.env` at or under cwd; `Read(//**/.env)` anywhere on the filesystem. Depth semantics (v2.1.214+): "Allow rules: `Edit(src/**)` matches only `<cwd>/src`… Deny and ask rules: `Read(secrets/**)` matches a directory named `secrets` at any depth"; `Edit(/src/**)` anchored to the settings file's directory; `Edit(**/src/**)` any depth. "In gitignore patterns, `*` matches within a single path segment… while `**` matches across directories." `~/` is home, `//` is filesystem root. — [permissions](https://code.claude.com/docs/en/permissions)
- Tool-name wildcards: deny/ask accept globs (`"*"`, `"mcp__*"`); allow globs only after a literal `mcp__<server>__` prefix (`mcp__puppeteer__*`, `mcp__github__get_*`); "An unanchored allow glob such as `"*"`… is skipped with a warning". — [permissions](https://code.claude.com/docs/en/permissions)
- `WebFetch(domain:github.com)` form and the warning that "Bash permission patterns that try to constrain command arguments are fragile" (e.g., `Bash(curl http://github.com/ *)`), recommending deny `curl`/`wget` + WebFetch domain rules + sandbox + PreToolUse hooks. — [permissions](https://code.claude.com/docs/en/permissions)
- `--allowedTools` uses the same syntax: `claude -p "…" --allowedTools "Bash(git diff *),Bash(git log *),Bash(git status *),Bash(git commit *)"`; "The space before `*` is important: without it, `Bash(git diff*)` would also match `git diff-index`." `--disallowedTools` = deny rules ("`"*"` removes every tool, and `"mcp__*"` removes every MCP tool"). `--tools` restricts built-in tools. — [headless](https://code.claude.com/docs/en/headless), [cli-reference](https://code.claude.com/docs/en/cli-reference)
- `--add-dir` grants file access but "doesn't discover most `.claude/` configuration from these directories"; persist with `permissions.additionalDirectories`. `--setting-sources user,project,local` picks which files load. — [cli-reference](https://code.claude.com/docs/en/cli-reference)

**Permission modes**
- Table (verbatim): `default` "Reads only"; `acceptEdits` "Reads, file edits, and common filesystem commands (`mkdir`, `touch`, `mv`, `cp`, etc.)"; `plan` "Reads, plus classifier-approved commands when auto mode is available"; `auto` "Everything, with background safety checks"; `dontAsk` "Reads and pre-approved tools; anything that would prompt is denied — Locked-down CI and scripts"; `bypassPermissions` "Everything — Isolated containers and VMs only". "`manual` [is] an alias" for `default`. "Deny rules block in every mode, including `bypassPermissions`… Allow rules have no effect in `bypassPermissions`." — [permission-modes](https://code.claude.com/docs/en/permission-modes)
- "With Claude Code v2.1.283 or later, auto mode is the built-in starting permission mode for interactive terminal and VS Code sessions." Managed controls: "Remove auto mode: set `permissions.disableAutoMode` to `"disable"` in managed settings; Block `bypassPermissions`: set `permissions.disableBypassPermissionsMode` to `"disable"`". `permissions.defaultMode` in managed settings sets org-wide starting mode. — [permission-modes](https://code.claude.com/docs/en/permission-modes)
- "Actions no mode auto-approves" include explicit ask rules, `AskUserQuestion`, `rm`/`rmdir` on critical paths, and reads outside working directories when `permissions.blockReadsOutsideWorkingDirectories` is on. Protected paths "are never auto-approved except in `bypassPermissions` mode". — [permission-modes](https://code.claude.com/docs/en/permission-modes)
- `--permission-mode` accepts `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`, `manual`; `--dangerously-skip-permissions` ≡ `bypassPermissions`; `--permission-prompts none` (v2.1.259+) denies anything a host can't answer in `-p` runs; `--restricted` (v2.1.248+) loads only managed settings and `--settings` and removes command-running tools. — [cli-reference](https://code.claude.com/docs/en/cli-reference), [headless](https://code.claude.com/docs/en/headless)

**Sandboxing**
- "The Bash sandbox is a boundary that the operating system enforces around the shell commands Claude runs… The sandbox covers shell commands only. Claude's file tools, MCP servers, and hooks run outside it." macOS uses Seatbelt; Linux/WSL2 need `bubblewrap` and `socat`; native Windows unsandboxed. Off by default; enable with `/sandbox` or `sandbox.enabled: true`. — [sandboxing](https://code.claude.com/docs/en/sandboxing)
- Defaults: writes allowed to the working directory, a per-user temp dir, and added directories; reads most of the machine; "Network — No direct route out. Connections go through a proxy… allowed domains, which start empty." Keys: `sandbox.filesystem.allowWrite/denyWrite/denyRead/allowRead/disabled`, `sandbox.network.allowedDomains/deniedDomains`, `sandbox.excludedCommands` (e.g. `["docker compose *"]`, runs unsandboxed with full access), `sandbox.allowUnsandboxedCommands: false` ("strict sandbox mode"), `sandbox.failIfUnavailable: true`, `credentials`, `allowManagedDomainsOnly`. Built on `@anthropic-ai/sandbox-runtime`. — [sandboxing](https://code.claude.com/docs/en/sandboxing)
- "Auto-allow… Claude Code approves a command automatically, with no prompt, when the command runs inside the sandbox"; "Content-scoped ask rules like `Bash(git push *)` still force a prompt even for sandboxed commands". The unsandboxed-retry escape hatch (`dangerouslyDisableSandbox`) can be disabled; "If you or your administrator disable the retry in managed settings… the sandbox becomes admin-required. Claude Code then ignores the settings in a repository's files that loosen the sandbox, `excludedCommands` entries included." — [sandboxing](https://code.claude.com/docs/en/sandboxing)
- One-session override: `claude --settings '{"sandbox": {"enabled": true, "allowUnsandboxedCommands": false}}'`. — [sandboxing](https://code.claude.com/docs/en/sandboxing)

**Trust and `-p` behaviour**
- "Without `--bare`, a `-p` session runs the hooks in a project's `.claude/settings.json` and connects the servers in its `.mcp.json`, even in a folder you've never trusted. A `-p` session shows no workspace trust dialog and no per-server approval prompt." `--bare` skips hooks, skills, commands, subagents, plugins, MCP, auto memory, CLAUDE.md and "will become the default for `-p` in a future release." — [headless](https://code.claude.com/docs/en/headless)
- `enableAllProjectMcpServers` and `enabledMcpjsonServers` "in a project's committed `.claude/settings.json` are ignored in an untrusted folder". — [mcp](https://code.claude.com/docs/en/mcp)

**Composed Swift/tvOS project `.claude/settings.json` (derived from documented syntax; untested)**
```json
{
  "permissions": {
    "allow": [
      "Bash(xcodebuild build *)",
      "Bash(xcodebuild test *)",
      "Bash(xcodebuild -list *)",
      "Bash(xcrun simctl *)",
      "Bash(swift build *)",
      "Bash(swift test *)",
      "Bash(swiftlint *)",
      "Bash(swiftformat *)",
      "Bash(swift-format *)",
      "Bash(xcodegen *)",
      "Bash(periphery scan *)",
      "Bash(solid-like-a-rock *)",
      "Bash(git diff *)", "Bash(git log *)", "Bash(git status *)",
      "mcp__XcodeBuildMCP__*"
    ],
    "ask": [
      "Bash(git push *)",
      "Bash(pod install *)",
      "Bash(swift package update *)",
      "Bash(xcrun altool *)",
      "Bash(xcrun notarytool *)",
      "Bash(fastlane *)"
    ],
    "deny": [
      "Edit(**/*.pbxproj)",
      "Edit(**/*.xcworkspacedata)",
      "Edit(**/Podfile.lock)",
      "Edit(**/Package.resolved)",
      "Edit(**/*.entitlements)",
      "Edit(**/*.xcconfig)",
      "Read(./.env)", "Read(./.env.*)",
      "Read(**/*.p12)", "Read(**/*.p8)", "Read(**/*.mobileprovision)", "Read(**/GoogleService-Info.plist)",
      "Bash(git push --force *)", "Bash(git push -f *)",
      "Bash(rm -rf *)",
      "Bash(curl *)", "Bash(wget *)"
    ],
    "defaultMode": "acceptEdits"
  },
  "sandbox": {
    "enabled": true,
    "network": { "allowedDomains": ["github.com", "*.apple.com", "swiftpackageindex.com"] }
  }
}
```
(Rule syntax from [permissions](https://code.claude.com/docs/en/permissions); file/secret deny set mirrors ios-template's "never read a secret-shaped file" list — [ios-template AGENTS.md](https://github.com/tomada1114/ios-template/blob/main/AGENTS.md); MCP allow glob form from [permissions](https://code.claude.com/docs/en/permissions). Caveat: `Bash(git push --force *)` only matches that spelling; per the docs `git push -f`, `git -C . push --force` etc. need their own rules or a hook/sandbox.)

### Inferences
- For a team repo, commit `deny`/`ask` rules (they apply before trust) and keep `allow` rules minimal; put personal allow lists in `settings.local.json` as ios-template does. The sandbox is the only mechanism that closes the `grep -r`/`/bin/rm`/`sh -c` holes in text-matching rules.
- Enterprise governance = managed-settings.json with `allowManagedPermissionRulesOnly`, `disableBypassPermissionsMode`, optionally `disableAutoMode`, `allowManagedHooksOnly`, MCP allowlist lock, and a strict sandbox with `failIfUnavailable`; macOS fleets can deliver this as a `com.anthropic.claudecode` profile via Jamf/Intune (MDM templates exist at `anthropics/claude-code/examples/mdm`).

### Gaps
- The settings-reference page listing every key (e.g., `includeCoAuthoredBy`, `cleanupPeriodDays` defaults) was not fetched in full; keys cited above come from the settings/example/managed pages.
- No official guidance on Xcode-specific sandbox allowances (e.g., DerivedData, `~/Library/Developer`) was found; `sandbox.filesystem.allowWrite` would be the documented lever.

---

## Key question 5: Custom slash commands vs skills — formats, frontmatter, `$ARGUMENTS`, `!` shell injection, iOS examples

### Takeaway
Since Claude Code 2.1.3 ("Merged slash commands and skills"), `.claude/commands/<name>.md` and `.claude/skills/<name>/SKILL.md` both create `/name` with the same frontmatter (`description`, `argument-hint`, `allowed-tools`, `model`, `disable-model-invocation`, `user-invocable`, `hooks`, `paths`, `context: fork`…); skills add a directory for supporting files and auto-invocation by Claude. Use `disable-model-invocation: true` for side-effecting workflows (release, deploy) and `` !`cmd` `` to inject live build/test output.

### Cited Findings
- "Custom commands have been merged into skills. A file at `.claude/commands/deploy.md` and a skill at `.claude/skills/deploy/SKILL.md` both create `/deploy` and work the same way. Your existing `.claude/commands/` files keep working. Skills add optional features: a directory for supporting files, frontmatter to control whether you or Claude invokes them, and the ability for Claude to load them automatically when relevant." Command files "support the same frontmatter except `name` and `paths`"; precedence: "A skill and a file in `.claude/commands/` | The skill". Namespacing: `.claude/commands/frontend/component.md` → `/frontend:component`. — [skills](https://code.claude.com/docs/en/skills) (the `/docs/en/slash-commands` URL now serves this page)
- CHANGELOG: "2.1.3 — Merged slash commands and skills, simplifying the mental model with no change in behavior"; "2.1.222 — Improved the refusal when Claude tries to invoke a skill with `disable-model-invocation`: Claude is now told to ask you to run the skill instead". — [CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)
- Locations: Enterprise `.claude/skills/<skill-name>/SKILL.md` in the managed settings directory; Personal `~/.claude/skills/…`; Project `.claude/skills/…` ("Commit it so your team gets it too"); Plugin `<plugin>/skills/…` as `/plugin-name:skill-name`. — [skills](https://code.claude.com/docs/en/skills)
- Frontmatter fields (verbatim descriptions): `name` ("Command name shown in the `/` menu. Defaults to the directory name."), `description` ("Claude uses this to decide when to apply the skill"), `when_to_use`, `argument-hint` ("Example: `[issue-number]`"), `arguments` (named positional), `disable-model-invocation` ("Set to `true` to prevent Claude from automatically loading this skill. Use for workflows you want to trigger manually"), `user-invocable` ("Set to `false` when only Claude should invoke the skill"), `allowed-tools` ("Tools Claude can use without asking permission during the turn that invokes this skill. The grant clears when you send your next message."), `disallowed-tools`, `model` (or `inherit`), `effort` (`low`…`max`), `context` (`fork` runs in a subagent), `agent`, `background`, `hooks` ("registers when the skill is invoked and keeps running for the rest of the session"), `paths` ("Glob patterns that limit when this skill is activated"), `shell` (`bash`/`powershell`). "All fields are optional. Only `description` is recommended." — [skills](https://code.claude.com/docs/en/skills)
- Invocation matrix (verbatim): default → user and Claude can invoke, description always in context; `disable-model-invocation: true` → user only, description not in context; `user-invocable: false` → Claude only. — [skills](https://code.claude.com/docs/en/skills)
- Arguments: `$ARGUMENTS` (all), `$ARGUMENTS[N]`/`$N` (0-based), `$name` (declared), `${CLAUDE_SKILL_DIR}`, `${CLAUDE_SESSION_ID}`; shell-style quoting; "When no placeholder receives an argument, Claude Code appends them as `ARGUMENTS: <value>`"; escape `\$1.00`. — [skills](https://code.claude.com/docs/en/skills)
- Shell injection: "The `` !`<command>` `` syntax runs shell commands before the skill content is sent to Claude. The command output replaces the placeholder"; multi-line via a fenced block opened with ```` ```! ````; "A failed command aborts the entire skill invocation"; commands are checked against permission rules; `"disableSkillShellExecution": true` disables; "2.1.290 — Changed skills and custom commands to refuse a `!` shell command [under some conditions]". — [skills](https://code.claude.com/docs/en/skills), [CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)
- Layout & size: `SKILL.md` + `reference.md` + `examples.md` + `scripts/helper.py`; "Keep `SKILL.md` under 500 lines"; body loads only on use. — [skills](https://code.claude.com/docs/en/skills)
- Verbatim examples:
  ```yaml
  ---
  name: deploy
  description: Deploy the application to production
  context: fork
  disable-model-invocation: true
  ---

  Deploy the application:
  1. Run the test suite
  2. Build the application
  3. Push to the deployment target
  ```
  ````markdown
  ---
  name: summarize-changes
  description: Summarizes uncommitted changes and flags anything risky. Use when the user asks what changed, wants a commit message, or asks to review their diff.
  ---

  ## Current changes

  !`git diff HEAD`

  ## Instructions

  Summarize the changes above in two or three bullet points, then list any risks you notice.
  ````
  — [skills](https://code.claude.com/docs/en/skills)
- Best-practices `fix-issue` skill (verbatim, `disable-model-invocation: true`, 8 numbered steps using `gh issue view`, tests, lint, commit, PR). — [best-practices](https://code.claude.com/docs/en/best-practices)
- In `-p` mode "User-invoked skills and custom commands work. Include `/skill-name` in the prompt string and Claude Code expands it before running." — [headless](https://code.claude.com/docs/en/headless)
- `/skills` lists skills and lets you cycle visibility; `skillOverrides` in settings (e.g. `"code-review": "user-invocable-only"`) controls who may invoke. — [commands](https://code.claude.com/docs/en/commands), [code-review](https://code.claude.com/docs/en/code-review)
- Real iOS skill catalog (ios-template): skills authored under `.agents/skills/` and mirrored byte-identically into `.claude/skills/` (`just agents-sync`/`just agents-check`); named skills include `tdd`, `create-pr`, `smart-commit`, `changing-gates` ("a file that enforces rather than implements"), `merging-dependency-prs`, `designing-errors`, `designing-core-logic`, `running-the-app` ("`just run`… `simctl` screenshots in dark mode and at large Dynamic Type sizes, deep links, simulated pushes"), `integrating-system-apis`, `building-swiftui-screens`, `localizing-the-app`, `recording-architecture-decisions`, `shipping-issues` (uses `/code-review`). — [ios-template AGENTS.md](https://github.com/tomada1114/ios-template/blob/main/AGENTS.md)
- Community iOS commands (keskinonur): `build.md`, `test.md`, `run-app.md` (via XcodeBuildMCP), `create-view.md`, `refactor-view.md`, `fix-build.md` ("clean build, analyze errors, and fix them one at a time"), `implement-feature.md` (stops after each task for approval), `plan-feature.md` ("DO NOT write any code. This is planning only."), sandbox variants, and a personal `~/.claude/commands/swift-style.md` running SwiftLint + swift-format. — [keskinonur/claude-code-ios-dev-guide](https://github.com/keskinonur/claude-code-ios-dev-guide)
- Other Swift skill sets exist as aggregator listings: Rudrank Riyam's `asc-skills` (App Store Connect/Xcode build/TestFlight/notarization skills) and tartinerlabs `xcode-skills`; content not fetched. — [agentskill.sh/@rudrankriyam (search result)](https://agentskill.sh/@rudrankriyam), [forums.swift.org thread (search result)](https://forums.swift.org/t/claude-code-skills-for-server-side-swift-xcode-cloud-15-open-source-skill-files-for-vapor-hummingbird-and-ci-cd/85851)

**Composed iOS/tvOS skills (derived from the documented syntax; untested)**
````markdown
<!-- .claude/skills/build-and-test/SKILL.md -->
---
name: build-and-test
description: Build the app for iOS and tvOS simulators and run unit tests. Use after any Swift change before claiming a task is done.
argument-hint: [scheme] [ios|tvos|all]
allowed-tools: Bash(xcodebuild *), Bash(xcrun simctl *), Read
---
## Available simulators
!`xcrun simctl list devices available | grep -E "iPhone|Apple TV" | head -20`

## Steps
1. `xcodebuild -scheme $0 -destination 'platform=iOS Simulator,name=iPhone 16' -quiet build test`
2. If `$1` is `tvos` or `all`: `xcodebuild -scheme $0 -destination 'platform=tvOS Simulator,name=Apple TV' -quiet build test`
3. Paste the last 30 lines of any failure and fix the root cause; never add `swiftlint:disable` or weaken a test.
````
````markdown
<!-- .claude/skills/triage-crash/SKILL.md -->
---
name: triage-crash
description: Symbolicate and triage a crash report or .ips file, then locate the responsible code path.
argument-hint: [path-to-crash]
disable-model-invocation: true
allowed-tools: Bash(xcrun *), Bash(atos *), Read, Grep
---
Crash file: $0
!`head -60 "$0"`
1. Identify the crashed thread and top app frames.
2. Symbolicate with `atos -o <dSYM> -arch arm64 -l <load address>` if addresses are unsymbolicated.
3. Map frames to source with Grep; propose a minimal fix and a regression test (Swift Testing).
````
````markdown
<!-- .claude/skills/release-checklist/SKILL.md -->
---
name: release-checklist
description: Walk the App Store / TestFlight release checklist. Human-triggered only; never uploads without explicit approval.
disable-model-invocation: true
context: fork
---
Current version/build: !`agvtool what-version -terse; agvtool what-marketing-version -terse1`
1. Confirm CHANGELOG `[Unreleased]` is moved to the version.
2. Run /build-and-test MyApp all.
3. STOP and ask for human sign-off before `xcrun altool`/`notarytool` or any tag push (see AGENTS.md › Security and human approval).
````
(Frontmatter/`!`/`$0` syntax from [skills](https://code.claude.com/docs/en/skills); the "stop and ask before release" convention from [ios-template AGENTS.md](https://github.com/tomada1114/ios-template/blob/main/AGENTS.md).)

### Inferences
- New work should use `.claude/skills/<name>/SKILL.md`; `.claude/commands/` is legacy-compatible only. Side-effecting iOS workflows (release, TestFlight upload, `pod install`) should carry `disable-model-invocation: true` so Claude cannot self-trigger them, and `allowed-tools` should be narrow.

### Gaps
- The `/docs/en/slash-commands` page now redirects to the skills page; a separate list of legacy-only frontmatter is not published beyond "same frontmatter except `name` and `paths`".
- Rudrank Riyam's and tartinerlabs' Swift skill files were not fetched (aggregator pages only).

---

## Key question 6: Subagents — `.claude/agents/*.md` frontmatter, Swift reviewer/test-writer/architecture-guardian definitions, invocation, concurrency

### Takeaway
Subagents are Markdown files with YAML frontmatter (`name` and `description` required; `tools`, `disallowedTools`, `model`, `permissionMode`, `maxTurns`, `skills`, `mcpServers`, `hooks`, `memory`, `isolation: worktree`, `omitClaudeMd`…), discovered from `.claude/agents/` (project), `~/.claude/agents/` (user), `--agents` JSON, plugins, or managed settings; each runs in a fresh context with only its system prompt, task, CLAUDE.md and git status; up to 20 run concurrently by default, nested three deep; invoke by description match, `@agent-name`, natural language, or `claude --agent`.

### Cited Findings
- Locations/priority (verbatim): "Managed settings | Organization-wide | 1 (highest); `--agents` CLI flag | Current session | 2; `.claude/agents/` | Current project | 3; `~/.claude/agents/` | All your projects | 4; Plugin's `agents/` directory | 5". Both directories "are scanned recursively"; "Claude Code watches these directories, so most changes take effect without a restart." — [sub-agents](https://code.claude.com/docs/en/sub-agents)
- Frontmatter (verbatim): `name` (required, ≤256 chars, no `:`), `description` (required, "When Claude should delegate"), `tools` (allowlist; inherits all if omitted), `disallowedTools`, `model` (`sonnet`, `opus`, `haiku`, `fable`, full ID, or `inherit`), `permissionMode` (`default`, `acceptEdits`, `auto`, `dontAsk`, `bypassPermissions`, `plan`, `manual`), `maxTurns`, `skills` (preloaded), `mcpServers`, `hooks`, `memory` (`user`/`project`/`local`), `color`, `background`, `effort`, `isolation` (`worktree`), `omitClaudeMd`, `initialPrompt`. "Plugin subagents ignore `hooks`, `mcpServers`, and `permissionMode` for security reasons." — [sub-agents](https://code.claude.com/docs/en/sub-agents)
- Verbatim examples:
  ```markdown
  ---
  name: code-reviewer
  description: Reviews code for quality and best practices
  tools: Read, Glob, Grep
  model: sonnet
  ---

  You are a code reviewer. When invoked, analyze the code and provide
  specific, actionable feedback on quality, security, and best practices.
  ```
  ```yaml
  ---
  name: db-reader
  description: Execute read-only database queries
  tools: Bash
  hooks:
    PreToolUse:
      - matcher: "Bash"
        hooks:
          - type: command
            command: "./scripts/validate-readonly-query.sh"
  ---
  ```
  — [sub-agents](https://code.claude.com/docs/en/sub-agents)
  ```markdown
  ---
  name: security-reviewer
  description: Reviews code for security vulnerabilities
  tools: Read, Grep, Glob, Bash
  model: opus
  ---
  You are a senior security engineer. Review code for:
  - Injection vulnerabilities (SQL, XSS, command injection)
  - Authentication and authorization flaws
  - Secrets or credentials in code
  - Insecure data handling

  Provide specific line references and suggested fixes.
  ```
  — [best-practices](https://code.claude.com/docs/en/best-practices)
- Invocation: automatic delegation by `description` ("include phrases like 'use proactively'"); natural language ("Use the code-reviewer subagent to…"); `@agent-<name>`; session-wide `claude --agent code-reviewer` or `"agent": "code-reviewer"` in settings; `--agents '{"reviewer":{"description":"Reviews code","prompt":"You are a code reviewer"}}'` (file path allowed with `-p`, v2.1.281+). `/agents` on v2.1.198+ "prints a reminder to ask Claude or edit the agent directories directly" (earlier versions had a wizard). — [sub-agents](https://code.claude.com/docs/en/sub-agents), [cli-reference](https://code.claude.com/docs/en/cli-reference), [commands](https://code.claude.com/docs/en/commands)
- Context isolation (verbatim): initial context is "Its own system prompt, not the Claude Code system prompt; The task message Claude writes when delegating; CLAUDE.md files (except for Explore and Plan); A git status snapshot (except for Explore and Plan); Any preloaded skills". "Only the final summary returns to the main conversation… Claude Code runs an output scan on subagent reports before Claude reads them." — [sub-agents](https://code.claude.com/docs/en/sub-agents)
- Concurrency: "The default concurrent limit is 20 running subagents… `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`. Nesting depth defaults to three layers… `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`." Foreground blocks; background runs concurrently with permission prompts surfacing in the main session. Resumable via `SendMessage`; transcripts at `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`. — [sub-agents](https://code.claude.com/docs/en/sub-agents)
- Built-ins: Explore (read-only, skips CLAUDE.md), Plan, general-purpose, `statusline-setup`, `claude-code-guide`. Guidance: keep descriptions short (>15,000 tokens combined warns), restrict tools "to enforce constraints", route cheap work to Haiku, "Set `memory: project` as the recommended default if you want persistent learning". — [sub-agents](https://code.claude.com/docs/en/sub-agents)
- Writer/Reviewer pattern and adversarial review: "A fresh context improves code review since Claude won't be biased toward code it just wrote"; "Use a subagent to review the rate limiter diff against PLAN.md… Report gaps, not style preferences." — [best-practices](https://code.claude.com/docs/en/best-practices)
- Subagent hooks: "`Stop` is converted to `SubagentStop`"; "v2.1.218: frontmatter hooks in project subagents require workspace trust." `SubagentStart` hooks can inject `additionalContext` but "cannot block subagent creation". — [hooks reference](https://code.claude.com/docs/en/hooks)
- Real Swift setups: ios-template defines "three named sub-agent tiers… `executor` (settled spec, clear pass/fail), `architect` (design judgment, review, complex multi-file work), `worker` (single-shot, tool-free writing or checking)… each pinned to a model alias and an effort level". johnrogers/claude-swift-engineering ships 12 agents: planning (Opus, read-only) `@swift-ui-design`, `@swift-architect`, `@tca-architect`; implementation `@swift-engineer`, `@swiftui-specialist`, `@swift-test-creator`, `@swift-code-reviewer`, `@swift-modernizer`…; utilities (Haiku) `@swift-documenter`, `@search`; principles "Read-Only Planning: planning agents cannot modify code" and "Plan File Coordination: agents share state via `docs/plans/<feature>.md`". — [ios-template AGENTS.md](https://github.com/tomada1114/ios-template/blob/main/AGENTS.md), [johnrogers/claude-swift-engineering](https://github.com/johnrogers/claude-swift-engineering)

**Composed Swift subagents (derived from documented frontmatter; untested)**
```markdown
<!-- .claude/agents/swift-reviewer.md -->
---
name: swift-reviewer
description: Reviews Swift/SwiftUI/tvOS diffs for concurrency, memory and architecture regressions. Use proactively after any multi-file Swift change and before opening a PR.
tools: Read, Grep, Glob, Bash(git diff *), Bash(git log *)
model: opus
permissionMode: default
maxTurns: 30
memory: project
---
You are a senior iOS/tvOS engineer. Review only the diff (`git diff main...HEAD`). Report findings with file:line and a concrete fix. Check, in order:
1. Swift 6 concurrency: non-Sendable values crossing actors, `@unchecked Sendable`, `nonisolated(unsafe)`, missing `@MainActor` on UI state, `Task {}` capturing `self` without `[weak self]` where the task outlives the view.
2. Memory: retain cycles in closures/delegates (`weak`/`unowned` capture lists, `weak var delegate`), Combine subscriptions not stored/cancelled, NotificationCenter observers not removed.
3. SwiftUI performance: heavy work in `body`, `@Observable`/`@State` misuse, view identity churn, `AnyView`, images decoded on main thread.
4. tvOS: focus (`@FocusState`, `.focusSection()`, `focusable`), Siri Remote interactions, no touch-only gestures.
5. Architecture: `Features/` must not import `Networking`/`Persistence`; views contain no business logic.
Flag only correctness or stated-requirement gaps; do not report style.
```
```markdown
<!-- .claude/agents/swift-test-writer.md -->
---
name: swift-test-writer
description: Writes Swift Testing (@Test/#expect) unit tests for Core logic against fakes, never mocks. Use when a change in Core lacks tests.
tools: Read, Grep, Glob, Edit, Write, Bash(swift test *), Bash(xcodebuild test *)
model: sonnet
permissionMode: acceptEdits
skills: tdd
---
Write the failing test first, run it, then stop. Test behavior and contracts, both happy and error paths; assert thrown error payloads with `#expect(throws:)`; no `sleep`, no shared mutable state.
```
```markdown
<!-- .claude/agents/architecture-guardian.md -->
---
name: architecture-guardian
description: Read-only check that a change respects module boundaries (Core <- UI, Core <- Platform, UI and Platform never import each other). Use before merging any change that touches imports, Package.swift or project.yml.
tools: Read, Grep, Glob, Bash(solid-like-a-rock *), Bash(swiftlint lint *)
model: haiku
disallowedTools: Edit, Write
---
Run the boundary tools and grep every changed file's `import` lines. Return PASS or a list of violations with the rule that forbids each. Never propose `// swiftlint:disable`.
```
(Frontmatter fields from [sub-agents](https://code.claude.com/docs/en/sub-agents); review topics from the question; boundary rule text from [ios-template](https://github.com/tomada1114/ios-template/blob/main/AGENTS.md).)

### Inferences
- An "architecture guardian" is most reliable when it is read-only (`disallowedTools: Edit, Write`) and runs deterministic tools, and when its output is also enforced in CI — a subagent alone is still advisory.
- Subagents inherit CLAUDE.md (unless `omitClaudeMd`) but NOT path-scoped rules until they Read matching files; reviewer prompts should restate the critical layering rules.

### Gaps
- The sub-agents page's final ~7,500 characters (likely troubleshooting) were not read.
- No official Swift-specific subagent definitions exist; the ones above are composed.

---

## Key question 7: Custom MCP servers for governance — `.mcp.json`, scopes, `claude mcp add`, env expansion, tool allowlisting, managed MCP, iOS examples

### Takeaway
Project MCP servers live in a committed `.mcp.json` (`{"mcpServers": {name: {type, command/url, args, env, headers}}}`), added with `claude mcp add --transport stdio|http --scope project|user|local`, with `${VAR}`/`${VAR:-default}` expansion in `command`, `args`, `env`, `url`, `headers`; tools are permissioned as `mcp__<server>__<tool>` (allow globs `mcp__server__*`). Organizations lock MCP with `managed-mcp.json` (exclusive) or `allowedMcpServers`/`deniedMcpServers` + `allowManagedMcpServersOnly`. The canonical iOS example is XcodeBuildMCP (now Sentry's MobileBuildMCP), which exposes build/test/simulator/device/log tools so Claude never has to compose raw `xcodebuild` commands.

### Cited Findings
- `claude mcp add` syntax (verbatim):
  ```bash
  # HTTP (recommended for remote servers)
  claude mcp add --transport http <name> <url>
  claude mcp add --transport http secure-api https://api.example.com/mcp \
    --header "Authorization: Bearer your-token"

  # SSE (deprecated)
  claude mcp add --transport sse <name> <url>

  # stdio (local process)
  claude mcp add [options] <name> -- <command> [args...]
  claude mcp add --env AIRTABLE_API_KEY=YOUR_KEY --transport stdio airtable \
    -- npx -y airtable-mcp-server
  ```
  "the `--` (double dash) separates Claude's own options… from the command and arguments that run the server"; `--env` must not be immediately followed by the server name. Short forms `-s`, `-t`, `-e`, `-H`. — [mcp](https://code.claude.com/docs/en/mcp)
- Scopes: `local` (default, `~/.claude.json`, "available only to you in the current project"), `project` ("shared with everyone in the project via the `.mcp.json` file"), `user`; precedence local > project > user > plugin > claude.ai connectors; `managedMcpServers` above all. "fields are not merged across scopes." — [mcp](https://code.claude.com/docs/en/mcp)
- `.mcp.json` format (verbatim):
  ```json
  {
    "mcpServers": {
      "shared-server": {
        "type": "http",
        "url": "https://example.com/mcp"
      }
    }
  }
  ```
  Env expansion: "`${VAR}`… `${VAR:-default}`… Expansion locations: `command`, `args`, `env`, `url`, and `headers`." Example `"url": "${API_BASE_URL:-https://api.example.com}/mcp"`, `"Authorization": "Bearer ${API_KEY}"`. Unset variables leave literal text and warn; `ANTHROPIC_API_KEY`/`ANTHROPIC_AUTH_TOKEN` read as empty in remote server config. — [mcp](https://code.claude.com/docs/en/mcp)
- Approval: "Claude Code prompts for approval in interactive sessions before using project-scoped servers from `.mcp.json`… `claude mcp reset-project-choices`"; in `-p`, SDK and cloud sessions it "loads project-scoped servers without asking" — mitigate with `disabledMcpjsonServers`, `--setting-sources`, or `--strict-mcp-config`. — [mcp](https://code.claude.com/docs/en/mcp)
- Tool naming: `mcp__<server>__<tool>`; plugin-bundled servers are `mcp__plugin_<plugin>_<server>__<tool>`; hook matcher example `mcp__database-tools__.*`. Permission allow glob `mcp__puppeteer__*`; deny `mcp__*`. — [mcp](https://code.claude.com/docs/en/mcp), [permissions](https://code.claude.com/docs/en/permissions)
- Limits: `MCP_TIMEOUT=10000 claude`, `MAX_MCP_OUTPUT_TOKENS` (default 25,000; warns at 10,000), per-server `"timeout": 600000` in `.mcp.json`. `claude mcp serve` exposes Claude Code itself as an MCP server. — [mcp](https://code.claude.com/docs/en/mcp)
- Managed MCP (verbatim): patterns table — "Disable MCP: `managed-mcp.json` with an empty server map; Fixed deployment: `managed-mcp.json` with the servers you want; Provided servers: `managedMcpServers` in managed settings; Approved catalog: `allowedMcpServers` + `allowManagedMcpServersOnly: true`; Plugin servers only: `strictPluginOnlyCustomization` with `mcp`; Soft allowlist…; Denylist only: `deniedMcpServers`". `managed-mcp.json` paths: `/Library/Application Support/ClaudeCode/managed-mcp.json`, `/etc/claude-code/managed-mcp.json`, `C:\Program Files\ClaudeCode\managed-mcp.json`; same format as `.mcp.json` (example includes a stdio `"company-internal": {"type":"stdio","command":"/usr/local/bin/company-mcp-server","args":["--config","/etc/company/mcp-config.json"],"env":{…}}`). Allow/deny entries: `{ "serverUrl": "https://*.internal.example.com/*" }`, `{ "serverCommand": ["npx","-y","@modelcontextprotocol/server-filesystem","."] }`, `{ "serverName": "dangerous-server" }` ("A `serverName` entry… is not a security control"). Evaluation: merge lists → denylist → allowlist. With `managed-mcp.json` present, `--mcp-config` exits with "You cannot dynamically configure MCP servers when an enterprise MCP config is present". — [managed-mcp](https://code.claude.com/docs/en/managed-mcp)
- XcodeBuildMCP: "A Model Context Protocol (MCP) server and CLI that provides tools for agent use when working on iOS and macOS projects"; requirements macOS 14.5+, Xcode 16.x+, Node 18+; `npx -y mobilebuildmcp@latest mcp` starts the server; install skills with `mobilebuildmcp init`; CLI examples `mobilebuildmcp simulator build --scheme MyApp --project-path ./MyApp.xcodeproj` and `simulator test --test-products-path … --simulator-name "iPhone 17"`; "requests xcodebuild to skip macro validation"; device tools need code signing; "per-workspace daemon for stateful operations (log capture, debugging, etc.)". The GitHub project page now titles itself MobileBuildMCP under getsentry. — [getsentry/XcodeBuildMCP README](https://github.com/getsentry/XcodeBuildMCP)
- Search-level: the Claude Code one-liner widely quoted is `claude mcp add XcodeBuildMCP -- npx -y xcodebuildmcp@latest mcp`; "The canonical repo is now github.com/getsentry/XcodeBuildMCP… Sentry announced in February 2026 that it had acquired the project"; Xcode 26.3+ has a built-in Claude Code agent whose MCP config lives under `~/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/.claude.json`. — [mcp.directory guide (search result)](https://mcp.directory/blog/xcodebuildmcp-complete-guide-2026), [glama listing (search result)](https://glama.ai/mcp/servers/getsentry/XcodeBuildMCP)
- Community CLAUDE.md pattern: "**IMPORTANT**: This project uses XcodeBuildMCP for all Xcode operations." with allow `mcp__xcodebuildmcp__*` and tool names like `mcp__xcodebuildmcp__build_sim_name_proj`, `mcp__xcodebuildmcp__test_sim_name_proj`, `mcp__xcodebuildmcp__clean`, `mcp__xcodebuildmcp__swift_package_test`. — [keskinonur/claude-code-ios-dev-guide](https://github.com/keskinonur/claude-code-ios-dev-guide)
- Steering guide: Anthropic's framework does not treat MCP as an instruction mechanism; plugins "bundle skills, subagents, hooks, and output styles" (and MCP servers per the plugins docs linked from best-practices). — [Steering Claude Code](https://claude.com/blog/steering-claude-code-skills-hooks-rules-subagents-and-more), [best-practices](https://code.claude.com/docs/en/best-practices)
- Hooks can call MCP tools (`type: "mcp_tool"` with `server`, `tool`, `input` using `${tool_input.file_path}`), which is how a project-specific "architecture-lint" MCP tool could be invoked deterministically after every edit. — [hooks reference](https://code.claude.com/docs/en/hooks)

**Composed project `.mcp.json` for an iOS/tvOS repo (derived from documented syntax; untested)**
```json
{
  "mcpServers": {
    "XcodeBuildMCP": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "mobilebuildmcp@latest", "mcp"]
    },
    "arch-lint": {
      "type": "stdio",
      "command": "swift",
      "args": ["run", "--package-path", "Tools/ArchLintMCP", "arch-lint-mcp"],
      "env": { "ARCH_CONFIG": "${CLAUDE_PROJECT_DIR:-.}/.solid.yml" }
    },
    "linear": {
      "type": "http",
      "url": "https://mcp.linear.app/mcp"
    }
  }
}
```
With `permissions.allow: ["mcp__XcodeBuildMCP__*", "mcp__arch-lint__*"]` and `permissions.ask: ["mcp__linear__*"]`. (Format and expansion rules from [mcp](https://code.claude.com/docs/en/mcp); allow-glob rule from [permissions](https://code.claude.com/docs/en/permissions). The `arch-lint` server is hypothetical; the Linear URL is illustrative and unverified.)

### Inferences
- A governance MCP server (architecture-lint, dependency-graph query, design-system lookup) is valuable because its tool output enters Claude's context as data and can be allowlisted precisely; but *enforcement* still needs a hook or CI gate — an MCP tool Claude may choose not to call is advisory.
- For enterprise iOS teams the "Approved catalog" pattern with `serverCommand` entries (exact `npx -y mobilebuildmcp@latest mcp`) is the documented way to let developers add XcodeBuildMCP while blocking unknown stdio servers.

### Gaps
- No published example of a team exposing "architecture-lint" or "design-system component lookup" via MCP was found with full source; the pattern is inferred.
- XcodeBuildMCP's current env-variable list (e.g., `XCODEBUILDMCP_ENABLED_WORKFLOWS`, `INCREMENTAL_BUILDS_ENABLED`) is only in its external docs site, which was not fetched; aggregator pages mention `INCREMENTAL_BUILDS_ENABLED` and `XCODEBUILDMCP_SENTRY_DISABLED`.

---

## Key question 8: Preventing architectural regressions in Swift — SwiftLint custom/analyzer rules, swift-format, Periphery, architecture tests, Danger-Swift, SPM boundaries, wiring as hooks/CI gates

### Takeaway
The strongest real-world pattern (ios-template) enforces each boundary twice with different tools on different jobs: a SwiftLint `custom_rules` regex (`no_ui_import_in_core`, severity error, `strict: true`) in the lint job and pre-commit hook, plus a Swift Testing `ArchitectureBoundaryTests` suite in the test job that also catches Foundation types no import ban can see. SwiftSyntax-based `solid-like-a-rock` and the bash `architecture-lint` add layer rules with a ratchet baseline; SwiftLint analyzer rules (`unused_import`, `unused_declaration`, `capture_variable`) need a compiler log; Periphery finds dead code but its OSS repo is archived; Danger-Swift reports results on PRs. Wire the single-file versions into PostToolUse hooks and the full versions into CI.

### Cited Findings

**SwiftLint**
- `.swiftlint.yml` keys (verbatim from README): `disabled_rules`, `opt_in_rules` ("all" enables all), `only_rules` (cannot combine with the other two), `analyzer_rules` ("Rules run only by `swiftlint analyze`. All are opt-in."), `included`, `excluded` ("Takes precedence over `included`"), `strict: false` ("Treat all warnings as errors"), `lenient`, `reporter`, `baseline`/`write_baseline`, `parent_config`/`child_config`; `${SOME_VARIABLE}` env expansion. — [realm/SwiftLint README](https://github.com/realm/SwiftLint/blob/main/README.md)
- Custom rules (verbatim):
  ```yaml
  custom_rules:
    pirates_beat_ninjas:
      included: ".*\\.swift"        # optional regex
      excluded: ".*Test\\.swift"    # optional regex
      name: "Pirates Beat Ninjas"   # optional
      regex: "([nN]inja)"
      capture_group: 0              # optional, default 0 (whole match)
      match_kinds:                  # optional
        - comment
        - identifier
      message: "Pirates are better than ninjas."  # optional
      severity: error               # optional
  ```
  "The regex runs with the `s` and `m` flags… If you use `only_rules`, include the literal string `custom_rules`". Swift-native custom rules require a Bazel build. — [realm/SwiftLint README](https://github.com/realm/SwiftLint/blob/main/README.md)
- Analyzer rules confirmed from source: `UnusedImportRule: CorrectableRule, AnalyzerRule` (`unused_import`, "All imported modules should be required to make the file compile"); `UnusedDeclarationRule: AnalyzerRule, CollectingRule` (`unused_declaration`, "Declarations should be referenced at least once within all files linted"); `CaptureVariableRule: AnalyzerRule` (`capture_variable`, "Non-constant variables should not be listed in a closure's capture list"); `TypesafeArrayInitRule: AnalyzerRule`; `ExplicitSelfRule: CorrectableRule, AnalyzerRule`. Memory-safety lint rules that are plain `Rule`s: `weak_delegate` ("Delegates should be weak to avoid reference cycles"), `unowned_variable_capture` ("Prefer capturing references as weak to avoid potential crashes"), `strong_iboutlet`. — [SwiftLint source: UnusedImportRule.swift](https://github.com/realm/SwiftLint/blob/main/Source/SwiftLintBuiltInRules/Rules/Lint/UnusedImportRule.swift), [UnusedDeclarationRule.swift](https://github.com/realm/SwiftLint/blob/main/Source/SwiftLintBuiltInRules/Rules/Lint/UnusedDeclarationRule.swift), [CaptureVariableRule.swift](https://github.com/realm/SwiftLint/blob/main/Source/SwiftLintBuiltInRules/Rules/Lint/CaptureVariableRule.swift), [WeakDelegateRule.swift](https://github.com/realm/SwiftLint/blob/main/Source/SwiftLintBuiltInRules/Rules/Lint/WeakDelegateRule.swift), [UnownedVariableCaptureRule.swift](https://github.com/realm/SwiftLint/blob/main/Source/SwiftLintBuiltInRules/Rules/Lint/UnownedVariableCaptureRule.swift)
- Analyze workflow (verbatim steps): clean DerivedData; `xcodebuild -workspace {WORKSPACE}.xcworkspace -scheme {SCHEME} > xcodebuild.log`; `swiftlint analyze --compiler-log-path xcodebuild.log`; "analyzer rules tend to be considerably slower than lint rules". Xcode Run Script phase: `if command -v swiftlint >/dev/null 2>&1; then swiftlint; else echo "warning: …"; fi`; SPM plugin `.package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "<version>")` with `.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")`; pre-commit `entry: swiftlint --fix --strict`; `--use-script-input-files` / `SCRIPT_INPUT_FILE_N`. Nested `.swiftlint.yml` per subdirectory (one merged per file; `--config` disables discovery). — [realm/SwiftLint README](https://github.com/realm/SwiftLint/blob/main/README.md)
- Real architecture rule (verbatim, ios-template `.swiftlint.yml`):
  ```yaml
  strict: true

  opt_in_rules:
    - all

  # No analyzer_rules: they only run under `swiftlint analyze` with a compiler
  # log, which no gate here invokes — listing them would advertise checks that
  # never fire. Revisit if a build-log-producing CI step is ever added.
  ...
  custom_rules:
    no_ui_import_in_core:
      included: 'Packages/MyAppKit/Sources/MyAppCore/.+\.swift$'
      regex: '^\s*(@[\w()]+\s+)*import\s+((typealias|struct|class|enum|protocol|let|var|func)\s+)?(SwiftUI|UIKit|AppKit|Cocoa|SwiftData|CoreData|CloudKit|UserNotifications|CoreLocation|Photos|PhotosUI|StoreKit|WidgetKit)\b'
      message: "MyAppCore must not import a UI, persistence, or OS-integration framework (SwiftUI, UIKit, AppKit, Cocoa, SwiftData, CoreData, CloudKit, UserNotifications, CoreLocation, Photos, PhotosUI, StoreKit, WidgetKit); put the adapter in MyAppPlatform behind a Core port (AGENTS.md › Architecture)."
      severity: error

    no_print_in_sources:
      included: '(^|/)(App/[^/]+|Packages/[^/]+/Sources/[^/]+/.+)\.swift$'
      excluded: '(^|/)[A-Za-z0-9]*Tests/'
      regex: '(^|[^\w.])(?<!func )(print|debugPrint|NSLog)\s*\('
      match_kinds:
        - identifier
      message: "Shipped code must not print to stdout — an app launched from the Home Screen discards it. Log through AppLog (os.Logger) instead, with a privacy annotation on anything user-derived (docs/architecture.md › Logging)."
      severity: error
  ```
  Comments note `included`/`excluded` "are substring matches against the whole file path, not repository-relative globs" and the regex handles `@preconcurrency`/`@_exported` attributes and `import struct SwiftUI.Color`. — [ios-template .swiftlint.yml](https://github.com/tomada1114/ios-template/blob/main/.swiftlint.yml)
- A regex pattern from a Medium article (search snippet only): a rule scoped to `Sources/Domain` with regex `import\s+(UIKit|Foundation|CoreLocation)` and `severity: error`. — [alpiopio.medium.com (search result)](https://alpiopio.medium.com/how-to-enforce-dependency-rules-with-swiftlint-custom-rules-a17e5f6734ae)

**Architecture test in Swift (verbatim excerpts, ios-template `ArchitectureBoundaryTests.swift`)**
```swift
import Foundation
import Testing

/// The second enforcement of the module boundaries (`AGENTS.md` › Architecture).
///
/// `MyAppCore` never imports a UI, persistence, or OS-integration framework —
/// `.swiftlint.yml`'s `no_ui_import_in_core` is the first enforcement, this suite the
/// second; the lint rule runs in the `lint` job and the pre-commit hook, this suite in the
/// `test` job, so removing either one still leaves the other catching a regression.
///
/// Core also never names a Foundation type an adapter owns (`URLSession`, `UserDefaults`):
/// Core imports Foundation, so no import ban can see one, and this suite is the only
/// enforcement.
///
/// `MyAppUI` and `MyAppPlatform` are siblings over Core and never import each other.
/// SwiftPM's target graph already withholds the modules, but only until someone adds a
/// dependency edge; this suite is what makes that edit fail a check rather than compile.
@Suite("Architecture boundary")
struct ArchitectureBoundaryTests {
    static let forbiddenModules = [
        "SwiftUI", "UIKit", "AppKit", "Cocoa",
        "SwiftData", "CoreData", "CloudKit",
        "UserNotifications", "CoreLocation", "Photos", "PhotosUI", "StoreKit", "WidgetKit",
    ]
    static let forbiddenFoundationTypes = ["URLSession", "UserDefaults"]
    ...
    static func pattern(forAnyOf modules: [String]) -> String {
        #"^\s*(@[\w()]+\s+)*import\s+((typealias|struct|class|enum|protocol|let|var|func)\s+)?("#
            + modules.joined(separator: "|")
            + #")\b"#
    }
    static func sourcesDirectory(of module: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(module, isDirectory: true)
    }
    static func expectNoImports(of modules: [String], in module: String) throws {
        let directory = sourcesDirectory(of: module)
        let files = swiftFiles(in: directory)
        try #require(!files.isEmpty, "no .swift files found under \(directory.path) — is the path resolution wrong?")
        let regex = try importRegex(forAnyOf: modules)
        for file in files {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() where line.firstMatch(of: regex) != nil {
                Issue.record("\(file.path):\(index + 1): forbidden import in \(module): \(line)")
            }
        }
    }
    @Test
    func `no MyAppCore source file imports a UI, persistence, or OS-integration framework`() throws {
        try Self.expectNoImports(of: Self.forbiddenModules, in: "MyAppCore")
    }
    ...
}
```
— [ios-template ArchitectureBoundaryTests.swift](https://github.com/tomada1114/ios-template/blob/main/Packages/MyAppKit/Tests/MyAppCoreTests/ArchitectureBoundaryTests.swift)
- The enforcement-layers table rows: "`.swiftlint.yml`'s `no_ui_import_in_core` + `ArchitectureBoundaryTests` | the hook, `just lint`, CI `lint`; `just test`, CI `test` | Core's import ban; Core never names `URLSession` or `UserDefaults`…; UI and Platform never import each other; no shipped module imports `MyAppTestSupport`"; "`scripts/coverage.sh` | `just test`, CI `test` | 80% line / 75% function coverage on `MyAppCore`"; CI jobs `lint` (ubuntu: swiftformat --lint + swiftlint --strict + shellcheck + actionlint + typos), `test` (runs-on `xcode-27`, `scripts/coverage.sh`), `app` (iOS Simulator build + XCUITest), `smoke` (Release launch). "`git commit --no-verify` bypasses the hook… CI is the backstop". — [ios-template AGENTS.md](https://github.com/tomada1114/ios-template/blob/main/AGENTS.md), [ios-template ci.yml](https://github.com/tomada1114/ios-template/blob/main/.github/workflows/ci.yml)

**SwiftSyntax / script-based boundary linters**
- solid-like-a-rock: "parses each `.swift` file with SwiftSyntax (a real syntax tree — no fragile regex / `grep`), finds every `import` statement, figures out which architectural layer the file belongs to, and fails if a layer imports something it shouldn't"; install `brew tap nenadvulic/solid-like-a-rock && brew install solid-like-a-rock`; `solid-like-a-rock init` generates `.solid.yml` from the real import graph, `--freeze` ("zero violations now, and the linter bites the moment a new cross-module dependency appears"), `--tca`, `--security`; run `solid-like-a-rock lint Sources` (or `--config .solid.yml Sources`); output `Sources/Presentation/HomeView.swift:5: error: SolidLikeARock: layer 'Presentation' must not import 'Data'`; non-zero exit for CI/Xcode Run Script; integrations doc covers "Xcode, GitHub Action / CI, SwiftPM command & build-tool plugins, Danger, Claude Code"; explicitly "Built for AI-assisted development… Works with… Claude Code, Cursor, Codex, Windsurf — since the guardrail lives in the build". Benchmark: 388 files/88 modules lint in 0.86 s. — [nenadvulic/solid-like-a-rock](https://github.com/nenadvulic/solid-like-a-rock)
- architecture-lint (bash, ratchet baseline): "Your module graph… is a list of `module|forbidden_import` pairs in the `BOUNDARIES` array… a violation is any line in that directory containing the import keyword followed somewhere by the forbidden module name as a whole word"; `./architecture-lint.sh --init-baseline` then `./architecture-lint.sh` fails "only on regressions"; also `no_singletons` (`static let shared`) with `// arch-exempt: singleton`; Swift fixture confirms `import CoreData` is not mistaken for `Data`. — [OrenSegal/architecture-lint](https://github.com/OrenSegal/architecture-lint)
- SPM: declared target dependencies limit what a module can import, and SPM rejects circular dependencies, but it cannot stop an allowed module from being imported — hence the test above. — [ios-template ArchitectureBoundaryTests.swift](https://github.com/tomada1114/ios-template/blob/main/Packages/MyAppKit/Tests/MyAppCoreTests/ArchitectureBoundaryTests.swift) (doc comment), [alpiopio.medium.com part 1 (search result)](https://alpiopio.medium.com/leveraging-swift-package-manager-to-maintain-clean-architecture-layers-in-ios-development-part-1-0ba9b439f665)

**swift-format / SwiftFormat**
- swift-format: `.swift-format` is JSON; defaults `version: 1`, `lineLength: 100`, `indentation: {"spaces": 2}`, `maximumBlankLines: 1`, `respectsExistingLineBreaks: true`, `lineBreakBeforeControlFlowKeywords: false`; `swift-format dump-configuration` prints defaults; rules go in a `rules` block. — [swift-format Configuration.md](https://github.com/swiftlang/swift-format/blob/main/Documentation/Configuration.md)
- 44 rules; lint-only ones include `NeverForceUnwrap`, `NeverUseForceTry`, `NeverUseImplicitlyUnwrappedOptionals`, `AllPublicDeclarationsHaveDocumentation`, `AvoidRetroactiveConformances`, `ValidateDocumentationComments`; format-capable ones include `OrderedImports`, `UseEarlyExits`, `UseExplicitNilCheckInConditions`, `NoAccessLevelOnExtensionDeclaration`, `FileScopedDeclarationPrivacy`. — [swift-format RuleDocumentation.md](https://github.com/swiftlang/swift-format/blob/main/Documentation/RuleDocumentation.md)
- SwiftFormat (nicklockwood) `.swiftformat` as used by ios-template: `--swiftversion 6.2`, `--indent 4`, `--maxwidth 100`, `--stripunusedargs closure-only`, `--wraparguments before-first`, `--extensionacl on-declarations`, `--decimalgrouping 3,4` (aligned with SwiftLint `number_separator`); SwiftLint `trailing_comma: mandatory_comma: true` aligned with SwiftFormat. — [ios-template .swiftformat](https://github.com/tomada1114/ios-template/blob/main/.swiftformat), [ios-template .swiftlint.yml](https://github.com/tomada1114/ios-template/blob/main/.swiftlint.yml)

**Periphery**
- "A tool to identify unused code in Swift projects"; `brew install periphery`; `periphery scan --setup`; `--schemes` for Xcode; `--retain-public`, `--retain-objc-accessible`; CI pattern `periphery scan --skip-build --index-store-path '../dd/Index.noindex/DataStore/'` (SwiftPM default `.build/debug/index/store`); `--format xcode`. **Caveat: "Periphery has moved to a commercial product, and the repository is archived and read-only."** — [peripheryapp/periphery README](https://github.com/peripheryapp/periphery/blob/master/README.md)

**Danger-Swift**
- Dangerfile.swift (verbatim):
  ```swift
  import Danger

  let danger = Danger()
  let allSourceFiles = danger.git.modifiedFiles + danger.git.createdFiles

  let changelogChanged = allSourceFiles.contains("CHANGELOG.md")
  let sourceChanges = allSourceFiles.first(where: { $0.hasPrefix("Sources") })

  if !changelogChanged && sourceChanges != nil {
    warn("No CHANGELOG entry added.")
  }
  message("Highlight something in the table")
  warn("Something pretty bad, but not important enough to fail the build")
  fail("Something that must be changed")
  markdown("Free-form markdown that goes under the table, so you can do whatever.")
  ```
  Install `brew install danger/tap/danger-swift`; SPM `.package(url: "https://github.com/danger/swift.git", from: "3.0.0")` + `swift run danger-swift command`; `danger-swift ci|pr <url>|local|edit`; GitHub Action `uses: danger/swift@3.15.0` with `args: --failOnErrors --no-publish-check` and `GITHUB_TOKEN`; Docker image `ghcr.io/danger/danger-swift` (one bundles SwiftLint). — [danger/swift README](https://github.com/danger/swift/blob/master/README.md)
- SwiftLint integration: `SwiftLint.lint(inline: true)` (results in the diff), `SwiftLint.lint(directory: "Sources", configFile: ".swiftlint.yml")`, `lintAllFiles: true` (needed for nested configs), `swiftlintPath:`; by default "only added or modified files are linted". The standalone `danger-swiftlint` repo is deprecated because the integration "is now built into Danger Swift". — [ashfurrow/danger-swiftlint README](https://github.com/ashfurrow/danger-swiftlint/blob/master/README.md)

**Wiring tools as gates Claude must pass**
- Official: "Give Claude a check it can run: tests, a build, a screenshot… As a deterministic gate: a Stop hook runs your check as a script and blocks the turn from ending until it passes." — [best-practices](https://code.claude.com/docs/en/best-practices)
- ios-template Stop/PR gate semantics: `just check` = "verify-hooks → fmt → lint → test-scripts → check-harness → test → build" before every PR; review checklist item 1 "`just check` passes". The pre-commit hook runs `scripts/lint.sh --staged-tree` on staged Swift files. — [ios-template AGENTS.md](https://github.com/tomada1114/ios-template/blob/main/AGENTS.md)

**Composed CI gate (GitHub Actions, macOS runner) that the agent's PR must pass (derived; untested)**
```yaml
name: Guardrails
on: [pull_request]
jobs:
  guardrails:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v6
      - run: brew install swiftlint swiftformat nenadvulic/solid-like-a-rock/solid-like-a-rock
      - name: Format check
        run: swiftformat --lint .
      - name: Lint (strict, custom architecture rules)
        run: swiftlint lint --strict --reporter github-actions-logging
      - name: Import boundaries (SwiftSyntax)
        run: solid-like-a-rock --config .solid.yml Sources
      - name: Build + architecture tests
        run: xcodebuild test -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
      - name: tvOS build
        run: xcodebuild build -scheme MyApp-tvOS -destination 'platform=tvOS Simulator,name=Apple TV' -quiet
      - name: Analyzer rules (unused_import/unused_declaration) on a fresh build log
        run: |
          xcodebuild -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 16' clean build > xcodebuild.log
          swiftlint analyze --compiler-log-path xcodebuild.log --strict
```
(Tool CLIs from their READMEs cited above; `swiftlint analyze --compiler-log-path` from [SwiftLint README](https://github.com/realm/SwiftLint/blob/main/README.md). The `--reporter github-actions-logging` flag is not shown in the README I read — verify with `swiftlint reporters`.)

### Inferences
- "Enforce twice, on different jobs" is the key resilience pattern: a regex lint rule can be disabled with a `// swiftlint:disable` the agent writes, but ios-template's AGENTS.md forbids that without sign-off and a second test-side check still fails CI.
- The agent-facing loop is: path-scoped rule *tells* Claude the boundary → PostToolUse hook *runs* the single-file lint on each edit (exit 2 feeds violations back) → Stop/agent hook or `/code-review` *verifies* before the turn ends → CI *gates* the PR.

### Gaps
- Could not fetch forums.swift.org or realm.github.io (DNS); SwiftLint analyzer rule facts were taken directly from source files instead of the rule directory.
- Periphery's successor commercial product and current CI story were not researched beyond the archived README.

---

## Key question 9: Automated review — Claude Code GitHub Action, headless `claude -p` scripts, `/review`, `/security-review`, Swift-tailored review prompts

### Takeaway
Three official layers: (1) `anthropics/claude-code-action@v1` in your own workflow (interactive `@claude` or automation `prompt:`; `claude_args` carries any CLI flag such as `--allowedTools`, `--max-turns`, `--model`; inline comments require `--allowedTools "mcp__github_inline_comment__create_inline_comment"`); (2) headless `claude -p` with `--output-format json`/`--json-schema`, `--max-turns`, `--allowedTools`, `--permission-mode dontAsk`, `--bare`; (3) bundled `/code-review` (`/review` is an alias since v2.1.223; `--comment`, `--fix`, effort levels) and `/security-review`, plus Anthropic's managed Code Review service (Team/Enterprise, ~$15–25 per review) customizable via `CLAUDE.md` and `REVIEW.md`.

### Cited Findings

**GitHub Action**
- Setup: `/install-github-app` (github.com only; needs `gh`; saves `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` secret; pushes a branch with `claude.yml` and optionally `claude-code-review.yml`). Manual: install the Claude GitHub App, add the secret, copy `examples/claude.yml`. — [github-actions](https://code.claude.com/docs/en/github-actions)
- `@claude` workflow (verbatim):
  ```yaml
  name: Claude Code
  on:
    issue_comment:
      types: [created]
    pull_request_review_comment:
      types: [created]
  jobs:
    claude:
      if: contains(github.event.comment.body, '@claude')
      runs-on: ubuntu-latest
      permissions:
        contents: write
        pull-requests: write
        issues: write
        id-token: write
        actions: read
      steps:
        - uses: actions/checkout@v6
          with:
            fetch-depth: 1
        - uses: anthropics/claude-code-action@v1
          with:
            anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
  ```
  "`id-token: write`: required for the Claude Code GitHub Action's default GitHub App authentication"; "`actions: read`: lets Claude read CI results on PRs". — [github-actions](https://code.claude.com/docs/en/github-actions)
- Review via the official plugin (verbatim):
  ```yaml
  name: Code Review
  on:
    pull_request:
      types: [opened, synchronize, ready_for_review, reopened]
  jobs:
    review:
      runs-on: ubuntu-latest
      permissions:
        contents: read
        pull-requests: read
        issues: read
        id-token: write
      steps:
        - uses: actions/checkout@v6
          with:
            fetch-depth: 1
        - uses: anthropics/claude-code-action@v1
          with:
            anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
            plugin_marketplaces: "https://github.com/anthropics/claude-code.git"
            plugins: "code-review@claude-code-plugins"
            prompt: "/code-review:code-review --comment ${{ github.repository }}/pull/${{ github.event.pull_request.number }}"
            claude_args: '--allowedTools "mcp__github_inline_comment__create_inline_comment"'
  ```
  "`--comment`: Claude posts its review on the pull request, as an inline comment on each issue it finds…"; "keep this line even though the skill's own `allowed-tools` frontmatter names the same tool, because the Claude Code GitHub Action starts the MCP server that posts inline comments only when `--allowedTools` in `claude_args` names it." Skips drafts/closed/trivial PRs and PRs Claude already commented on. Fork PRs don't get secrets. — [github-actions](https://code.claude.com/docs/en/github-actions)
- Modes: no `prompt` → interactive (`@claude`); `prompt` → automation. Trigger checks: write access (or `allowed_non_write_users` + own `github_token`), human actor (`allowed_bots`). — [github-actions](https://code.claude.com/docs/en/github-actions)
- Inputs (verbatim subset): `prompt`, `claude_args` ("Additional arguments to pass directly to Claude CLI (e.g., `--max-turns 10 --model …`)"), `anthropic_api_key`, `claude_code_oauth_token`, `anthropic_federation_rule_id`/`anthropic_organization_id` (OIDC, no stored key), `track_progress`, `include_fix_links` (default true), `base_branch`, `use_sticky_comment`, `classify_inline_comments` (default true; Haiku filters test/probe comments), `github_token` ("Only include this if you're connecting a custom GitHub app"), `trigger_phrase` (default `@claude`), `assignee_trigger`, `label_trigger`, `branch_prefix` (`claude/`), `settings` ("JSON string or path"), `additional_permissions`, `use_commit_signing`, `ssh_signing_key`, `allowed_bots`, `allowed_non_write_users` ("RISKY"), `plugin_marketplaces`, `plugins`, `path_to_claude_code_executable`. Deprecated: `mode`, `direct_prompt`→`prompt`, `custom_instructions`→`--append-system-prompt`, `max_turns`→`claude_args: "--max-turns 5"`, `allowed_tools`→`--allowedTools`, `mcp_config`→`--mcp-config`. Output: `structured_output` (JSON string from `--json-schema`). — [claude-code-action docs/usage.md](https://github.com/anthropics/claude-code-action/blob/main/docs/usage.md)
- Verbatim example `pr-review-comprehensive.yml` (prompt covers Code Quality, Security, Performance "memory leaks or resource issues", Testing, Documentation; `track_progress: true`; `claude_args: --allowedTools "mcp__github_inline_comment__create_inline_comment,Bash(gh pr comment:*),Bash(gh pr diff:*),Bash(gh pr view:*)"`) and `pr-review-filtered-paths.yml` (triggers on `paths:` globs — swap in `**/*.swift`). — [examples/pr-review-comprehensive.yml](https://github.com/anthropics/claude-code-action/blob/main/examples/pr-review-comprehensive.yml), [examples/pr-review-filtered-paths.yml](https://github.com/anthropics/claude-code-action/blob/main/examples/pr-review-filtered-paths.yml)
- Cost controls: "Keep your `CLAUDE.md` concise… Set `--max-turns` in `claude_args`… workflow-level timeouts… concurrency controls". Cloud providers via `use_bedrock`/`use_vertex`/`use_foundry` with OIDC. — [github-actions](https://code.claude.com/docs/en/github-actions)

**Headless / CI scripts**
- `claude -p "…" --allowedTools "Read,Edit,Bash"`; exit code 0/non-zero; `--output-format text|json|stream-json`; `--json-schema '{…}'` → `structured_output`; `jq -r '.result'`; `--max-turns 3`; `--max-budget-usd 5.00`; `--permission-mode dontAsk` ("Claude Code denies every call that would otherwise prompt, which is useful for locked-down CI runs"); `--permission-prompts none` (v2.1.259+); `--bare` ("recommended mode for scripted and SDK calls"; needs `ANTHROPIC_API_KEY`); `--continue`/`--resume <id>`; `--no-session-persistence`; `--append-system-prompt`. — [headless](https://code.claude.com/docs/en/headless), [cli-reference](https://code.claude.com/docs/en/cli-reference)
- Verbatim review script:
  ```bash
  gh pr diff "$1" | claude -p \
    --append-system-prompt "You are a security engineer. Review for vulnerabilities." \
    --output-format json
  ```
  and the linter pattern `"lint:claude": "git diff main | claude -p \"you are a typo linter. for each typo in this diff, report filename:line on one line and the issue on the next. return nothing else.\""` ("Piping the diff means Claude doesn't need Bash permission to read it"). — [headless](https://code.claude.com/docs/en/headless)
- Fan-out loop: `claude -p "Migrate $file…" --allowedTools "Edit,Bash(git commit *)" --permission-mode dontAsk`. — [best-practices](https://code.claude.com/docs/en/best-practices)
- `system/init` in `stream-json` exposes `plugin_errors` and `mcp_server_errors` so "a CI gate can fail on a non-empty array". — [headless](https://code.claude.com/docs/en/headless)

**Built-in review commands**
- `/code-review`: "reviews your branch's commits ahead of its upstream plus any uncommitted changes… pass a target: a file path, a PR number, a branch name, or a ref range such as `main...my-feature`"; flags `--fix`, `--comment` (GitHub inline comments or GitLab note), `--post`, `--max-findings <n|all|default>` (v2.1.288+); effort `low`…`max` ("At `low`, the review reports the findings it's most confident in"); runs as a background subagent; "`/review` is an alias of `/code-review`; before v2.1.223, it was a separate command that ran a single-pass, read-only review of a GitHub pull request"; "`/simplify` runs a separate cleanup-only review"; "The review follows your `CLAUDE.md`… but it doesn't read `REVIEW.md`"; `/code-review ultra` escalates to cloud ultrareview; `claude ultrareview 1234 --json` for CI. — [code-review](https://code.claude.com/docs/en/code-review), [cli-reference](https://code.claude.com/docs/en/cli-reference)
- `/security-review`: "Analyze the changes on your current branch for security vulnerabilities. Reviews the diff between your branch and origin's default branch, identifying risks like injection, auth issues, and data exposure. Needs an `origin` remote". — [commands](https://code.claude.com/docs/en/commands)
- Managed Code Review service: Team/Enterprise research preview; "A fleet of specialized agents examine the code changes… then a verification step checks candidates against actual code behavior"; severities 🔴 Important / 🟡 Nit / 🟣 Pre-existing; "check run always completes with a neutral conclusion"; gate merges yourself by parsing `bughunter-severity:` JSON from the check run (`gh api repos/OWNER/REPO/check-runs/CHECK_RUN_ID --jq '.output.text | split("bughunter-severity: ")[1] | split(" -->")[0] | fromjson'`); triggers Once/Every push/Manual, `@claude review`, `@claude review always` (behavior change July 2026); "Each review averages $15-25". `REVIEW.md` tunes severity, nit caps, skip rules, repo-specific checks, verification bar. — [code-review](https://code.claude.com/docs/en/code-review)
- `REVIEW.md` example (verbatim) with sections "What Important means here", "Cap the nits" ("Report at most five Nits per review"), "Do not report" ("Anything CI already enforces: lint, formatting, type errors; Generated files…"), "Always check". — [code-review](https://code.claude.com/docs/en/code-review)

**Composed Swift-tailored review assets (derived; untested)**
```markdown
<!-- REVIEW.md (read by Anthropic's managed Code Review; format per code-review docs) -->
# Review instructions
## What Important means here
Reserve Important for: data races or `@unchecked Sendable` without proof; retain cycles (closures capturing `self` strongly in long-lived tasks/Combine sinks, strong delegates); main-thread blocking or image decoding in SwiftUI `body`; tvOS views unreachable by focus; `Features/` importing `Networking`/`Persistence`; force unwraps/`try!` in production code; any `.pbxproj`, lockfile, entitlement or signing change.
## Do not report
- Formatting and anything SwiftLint/swiftformat/`solid-like-a-rock` already enforce in CI
- `Package.resolved` churn from an approved dependency bump
## Always check
- New Core logic has Swift Testing coverage for happy and error paths
- `os.Logger` privacy annotations on user-derived values
- Shared files compile for both iOS and tvOS (`#if os(tvOS)` where needed)
```
```bash
# scripts/claude-review-swift.sh — headless PR review in CI (composed)
gh pr diff "$1" | claude --bare -p \
  --output-format json --max-turns 4 --permission-mode dontAsk \
  --append-system-prompt-file .claude/review/swift-reviewer.txt \
  --json-schema '{"type":"object","properties":{"blocking":{"type":"array","items":{"type":"string"}},"nits":{"type":"array","items":{"type":"string"}}},"required":["blocking","nits"]}' \
  | jq '.structured_output'
```
with `.claude/review/swift-reviewer.txt` restating the five Swift focus areas (concurrency, memory/retain cycles, SwiftUI performance, tvOS focus, module boundaries). (Flags from [headless](https://code.claude.com/docs/en/headless) and [cli-reference](https://code.claude.com/docs/en/cli-reference); REVIEW.md shape from [code-review](https://code.claude.com/docs/en/code-review).)

### Inferences
- For a Swift repo on GitHub, the cheapest robust setup is: `pr-review-filtered-paths.yml` with `paths: ["**/*.swift", "**/project.yml", "**/Package.swift"]`, `--max-turns`, and the inline-comment MCP tool; or the official `code-review` plugin workflow. Teams on Team/Enterprise can add the managed service and parse the severity check-run for a merge gate.
- Review prompts should explicitly scope to the diff and name the Swift-specific defect classes; the official examples are language-agnostic.

### Gaps
- No Anthropic-published Swift/tvOS review prompt exists; the one above is composed.
- Hackernoon's "governance layer" article and HumanLayer's "Writing a Good CLAUDE.md" (both listed in awesome-claude-code) could not be fetched (DNS blocked); their specific claims are not included.
- The exact text of `examples/claude.yml` in claude-code-action was downloaded but is the same shape as the docs example above.

---

### Cross-cutting dates and versions worth stating in the playbook (appendix to Key question 9)
- `.claude/rules/` introduced in 2.0.64; `InstructionsLoaded` hook 2.1.69; path-scoped rules fixed for Write/Edit in 2.1.288 and for Bash views in 2.1.293. — [CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)
- Slash commands merged into skills in 2.1.3. — [CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)
- `PermissionRequest` hook 2.0.45; prompt/agent hooks (plugins) 2.1.0; PreCompact blocking 2.1.105; Stop `additionalContext` 2.1.163. — [CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)
- Auto mode became the default starting mode in 2.1.283; `/doctor prompt-audit` 2.1.283; `--permission-prompts` 2.1.259; `--restricted` 2.1.248; `/review` became an alias of `/code-review` in 2.1.223; `--max-findings` 2.1.288. — [permission-modes](https://code.claude.com/docs/en/permission-modes), [memory](https://code.claude.com/docs/en/memory), [headless](https://code.claude.com/docs/en/headless), [cli-reference](https://code.claude.com/docs/en/cli-reference), [code-review](https://code.claude.com/docs/en/code-review)
- Anthropic "Steering Claude Code" post: June 18 2026. Managed Code Review `@claude review` semantics changed July 2026. — [Steering Claude Code](https://claude.com/blog/steering-claude-code-skills-hooks-rules-subagents-and-more), [code-review](https://code.claude.com/docs/en/code-review)
- tomada1114/ios-template adopted path-scoped rules + format-on-edit hook on Sep 30 2026 (issue #5). — [ios-template#5](https://github.com/tomada1114/ios-template/issues/5)
- Periphery OSS repo archived (commercial successor); `danger-swiftlint` deprecated in favor of built-in Danger Swift support; XcodeBuildMCP moved to getsentry (renamed MobileBuildMCP on its README). — [periphery README](https://github.com/peripheryapp/periphery/blob/master/README.md), [danger-swiftlint README](https://github.com/ashfurrow/danger-swiftlint/blob/master/README.md), [getsentry/XcodeBuildMCP](https://github.com/getsentry/XcodeBuildMCP)

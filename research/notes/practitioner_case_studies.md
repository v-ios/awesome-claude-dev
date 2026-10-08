# Claude Code for Apple-platform development: practitioner case studies (2025 - Oct 2026)

**Scope:** first-hand accounts from well-known iOS/macOS/tvOS engineers and company engineering teams about using Claude Code (and closely related agent tooling) for native Swift/SwiftUI/UIKit/tvOS work, Jan 2025 - Oct 2026.

**Access / provenance note (important for the report writer):** the research proxy in this session blocked direct fetches of nearly every blog host (steipete.me, indragie.com, dimillian.medium.com, shopify.engineering, blog.duolingo.com, simonwillison.net, news.ycombinator.com, hackingwithswift.com, heise.de, blakecrosley.com, twocentstudios.com, kean.blog). Everything below therefore comes from search-engine excerpts of the cited primary pages plus secondary coverage. Quotations marked **[snippet]** were captured verbatim from search excerpts of the cited page; they are short and should be spot-checked against the URL before being reproduced in a published report. Where only secondary coverage was available, that is stated. Dates are given wherever the source exposed them; Claude Code and Xcode changed rapidly across this window (Claude Code 1.x in mid-2025; Claude Code 2.0.x + Opus 4.5 by Dec 2025; Xcode 26.3 with native Claude Agent SDK integration in Feb 2026; Claude Code Desktop iOS Simulator pane in public beta Jul-Sep 2026).

---

## Key Question 1: What have named top-tier practitioners publicly written or said about Claude Code for Apple platforms?

### Takeaway
The most substantive first-hand write-ups come from Indragie Karunaratne (Jul 2025), Peter Steinberger (Jun-Oct 2025, many posts), Thomas Ricouard (May-Jun 2025), Alexander Grebenyuk/kean (Jun 2025), Christopher Trott/twocentstudios (Jun, Jul, Dec 2025), Donny Wals (2026), Jacob Bartlett (2025-Sep 2026), plus "tooling" contributions (skills/rule files) from Paul Hudson, Antoine van der Lee, Rudrank Riyam and Steinberger. The consensus across them: Claude Code is strong at SwiftUI and tedious porting, mediocre at modern Swift Concurrency and Xcode project plumbing, and only becomes reliable once it is given a closed build-run-observe loop. No substantive first-hand Claude Code accounts were found for Christian Selig, Jordan Morgan, Sean Allen, Majid Jabrayilov, Matt Gallagher, Marco Arment/ATP, Sebastiaan de With, Ben Scheirman, Krzysztof Zabłocki or Noah Gilmore.

### Cited Findings

**Indragie Karunaratne — "I Shipped a macOS App Built Entirely by Claude Code" (published ~Jul 6, 2025)**
- Credentials: building Mac software since 2008; now at Sentry working on AI agents for debugging (per search summaries of the post). Built *Context*, a native macOS app for debugging MCP servers (source: github.com/indragiek/Context). — [indragie.com](https://www.indragie.com/blog/i-shipped-a-macos-app-built-entirely-by-claude-code); [Simon Willison summary, Jul 6 2025](https://simonwillison.net/2025/Jul/6/macos-app-built-entirely-by-claude-code/)
- Scale: ~20,000 lines of code, of which he wrote fewer than 1,000 by hand. [snippet] "he wrote less than 1,000 lines by hand out of the 20,000 lines of code". — [Simon Willison](https://simonwillison.net/2025/Jul/6/macos-app-built-entirely-by-claude-code/); [9to5Mac, Jul 8 2025](https://9to5mac.com/2025/07/08/context-is-a-native-macos-app-that-was-almost-entirely-written-by-ai/)
- Language assessment: Claude Code is [snippet] "okay at Swift and good at SwiftUI"; it "didn't work out of the box with zero effort". — [indragie.com via search excerpt](https://www.indragie.com/blog/i-shipped-a-macos-app-built-entirely-by-claude-code)
- Concurrency: Swift up to 5.5 is fine, but Swift Concurrency (5.5+) trips it up; he calls the concurrency model a sharp break that "trips up experienced engineers too". Legacy Objective-C / AppKit / UIKit APIs keep resurfacing even when a modern Swift or SwiftUI option exists. Secondary (heise) phrasing: [snippet] "Claude Code had a good command of Swift features up to version 5.5 but had difficulties with Swift Concurrency... The system often falls back on outdated Objective-C APIs instead of using modern Swift alternatives. However, Claude Code has shown its better side with SwiftUI." — [heise.de, Jul 2025](https://www.heise.de/en/news/When-AI-programs-a-Mac-app-Developer-reports-on-experiences-10480791.html)
- Compiler: it sometimes hit SwiftUI type-checker timeouts and recovered by refactoring view bodies into smaller expressions. — [Simon Willison](https://simonwillison.net/2025/Jul/6/macos-app-built-entirely-by-claude-code/)
- Verification: the build/test/debug loop worked for Swift, but UI checking was manual: [snippet] "There isn't a good equivalent to Playwright yet, so the author had to take over to interact with the UI and drop in screenshots of problems." — [Simon Willison](https://simonwillison.net/2025/Jul/6/macos-app-built-entirely-by-claude-code/); heise: [snippet] "For troubleshooting, screenshots can be inserted directly into Claude Code." — [heise.de](https://www.heise.de/en/news/When-AI-programs-a-Mac-app-Developer-reports-on-experiences-10480791.html)
- Feedback loops as the central lever: [snippet] "Claude is most useful when it's capable of independently driving feedback loops"; heise: "The system should be able to compile, test, and correct errors independently." — [heise.de](https://www.heise.de/en/news/When-AI-programs-a-Mac-app-Developer-reports-on-experiences-10480791.html)
- CLAUDE.md: he published a snippet from the Context project's CLAUDE.md steering toward SwiftUI-first design, the most modern macOS APIs, and Swift 6 with async/await, actors and macros; he layers task-specific context by pointing Claude at particular docs/source files; he treats context management as the central difficulty, noting auto-compaction "can miss important details or carry forward low-quality context from earlier mistakes". (All via search summary of the post.) — [indragie.com](https://www.indragie.com/blog/i-shipped-a-macos-app-built-entirely-by-claude-code)
- Tooling workaround: secondary coverage of his X posts says Claude initially struggled to invoke xcodebuild correctly and he worked around it with XcodeBuildMCP and custom instructions. — [search summary citing his X posts; secondhand]
- Polish: [snippet] "Asking for more polished native interfaces works surprisingly well"; mock data for early screenshots "looked real enough to judge the design"; SwiftUI output described as [snippet] "an accurate but somewhat ugly rendering of the UI, and further iteration is needed". — [Simon Willison](https://simonwillison.net/2025/Jul/6/macos-app-built-entirely-by-claude-code/)
- Release automation (Jun 26, 2025 X post): had Claude Code write a script to bump versions, generate release notes from the changelog, build/code-sign/notarize/package the app, update the Sparkle appcast, tag and upload release artifacts to GitHub. — [x.com/indragie](https://x.com/indragie/status/1938055943130124379)
- Cost/productivity claim: [snippet] "the most exciting thing is that he is now able to scratch his coding itch and ship polished side projects again", comparing the gain to "an extra 5 hours every day for $200 a month" (Claude Max). — [Simon Willison](https://simonwillison.net/2025/Jul/6/macos-app-built-entirely-by-claude-code/)
- UX opinion (Jul 2025): "Claude Code is great but I doubt a terminal interface will end up being the ideal UX." — [x.com/indragie](https://x.com/indragie/status/1945293451668369509)
- Discussion threads: HN item 44481286 (could not be fetched). — [news.ycombinator.com](https://news.ycombinator.com/item?id=44481286)

**Peter Steinberger — PSPDFKit founder; OpenClaw creator; GitHub profile now says "Now at OpenAI, working on agents"**
- "Claude Code is My Computer" (Jun 3, 2025): runs Claude Code with permission prompts disabled (`--dangerously-skip-permissions`); says this returned roughly an hour of his day and his Mac has stayed intact for two months despite Anthropic docs reserving the flag [snippet] "only for Docker containers with no internet"; uses it for macOS housekeeping (e.g. `killall Dock` after plist edits) and a machine migration done in stages in about an hour. — [steipete.me](https://steipete.me/posts/2025/claude-code-is-my-computer); HN thread [44170967](https://news.ycombinator.com/item?id=44170967) (an HN commenter warned about prompt-injection leaking keys)
- Swift 6 strict concurrency doc (Jun 25, 2025 X post): "I compiled a comprehensive doc that pimps Claude's knowledge to write Swift 6 with Strict Concurrency. Get the markdown and copy it into a docs/ folder of your project and instruct Claude in CLAUDE md to read it whenever it writes Swift. Helps a lot!!" (file: agent-rules/docs/swift-concurrency.md). — [x.com/steipete](https://x.com/steipete/status/1937816669075689840)
- "give me options" prompt pattern (Jun 23, 2025): "'give me options' for Claude Code is so powerful. I was lazy and asked it for a fix, but wasn't a fan, so I asked for options. I learned an approach I totally didn't think of... vibe coding -> agentic engineering". — [x.com/steipete](https://x.com/steipete/status/1937184376657265077)
- Vibe Meter (macOS menu-bar app for tracking AI spend, 2025): first Mac app, ~3 days of work begun as a live workshop demo on Swift 6 + SwiftUI; menu-bar UI forced AppKit (arrowless popover, settings from menu item needed reflection workaround); signing/notarization/distribution were harder than coding; Sparkle in a sandboxed app needed Mach-lookup entitlements; codebase reached ~47,000 lines of Swift at 92% test coverage, much of it written by Claude Code. — [Vibe Meter post](https://steipete.me/posts/2025/vibe-meter-monitor-your-ai-costs); [Vibe Meter 2.0](https://steipete.me/posts/2025/vibe-meter-2-claude-code-usage-calculation); [Code Signing and Notarization: Sparkle and Tears](https://steipete.me/posts/2025/code-signing-and-notarization-sparkle-and-tears)
- Migrated 700+ tests from XCTest to Swift Testing across two projects with AI assistance (Jun 2025). — [steipete.me posts index](https://steipete.me/posts)
- "The Future of Vibe Coding: Building with AI, Live and Unfiltered" (2025) — exists; content not retrievable here. — [steipete.me](https://steipete.me/posts/2025/the-future-of-vibe-coding)
- Peekaboo: macOS CLI + MCP server letting agents capture screenshots and drive GUIs (Screen Recording + Accessibility permissions; Swift tools 6.2 with strict concurrency on; v3 moved see/click/type into the CLI; clients listed: Codex, Claude Code, Cursor). — [github.com/steipete/Peekaboo](https://github.com/steipete/Peekaboo); [peekaboo.sh](https://peekaboo.sh/)
- Tachikoma: "The story of how I built a modern Swift AI SDK completely with Claude Code, inspired by Vercel's AI SDK design". — [steipete.me page 2](https://steipete.me/page/2)
- "Just Talk To It - the no-bs Way of Agentic Engineering" (~Oct 2025): says he has fully moved to Codex CLI and [snippet] "used to like Claude Code but can't stand it anymore"; runs 3-8 agents in a 3x3 terminal grid, mostly in the same folder (tried worktrees/PRs, went back); agents make their own atomic commits of only the files they edited; notes Claude supports hooks (Codex didn't) but "models will get around a hook if they're determined to"; cites ~230k usable context in Codex vs 156k in Claude and says Claude "gets unreliable well before it fills its window". — [steipete.me](https://steipete.me/posts/just-talk-to-it)
- Aug 2025: "Ghostty, VS Code on the side, and Claude Code as my main driver." — [steipete.me via search excerpt](https://steipete.me/)
- Essential reading list for agentic engineers. — [steipete.me](https://steipete.me/posts/2025/essential-reading)

**Thomas Ricouard — Ice Cubes (open-source SwiftUI Mastodon client), ex-Google, Medium iOS; reported joining OpenAI Mar 10, 2026 (secondhand, manton.org)**
- "Vibe coding an iOS app with Claude 4" (May 23, 2025): tests Claude 4 by vibe-coding a SwiftUI blog app in Cursor. — [dimillian.medium.com](https://dimillian.medium.com/vibe-coding-an-ios-app-with-claude-4-f3b82b152f6d)
- "Building iOS apps with Cursor and Claude Code" (Jun 4, 2025): moved from Cursor's own agent, then Claude Code in a terminal, to Claude Code inside Cursor ("the Cursor integration is so good that he switched to it"); [snippet] "nothing comes close to Claude's code"; "It is quite good at SwiftUI, and it does far more than vanilla Cursor without heavy prompting"; Claude "consistently finds the correct way to do things and fixes issues". — [dimillian.medium.com](https://dimillian.medium.com/building-ios-apps-with-cursor-and-claude-code-ee7635edde24)
- Joined OpenAI (reported): "credits him with work on the Medium iOS app, Ice Cubes, and Codex Monitor" — secondhand relay of an X post. — [manton.org, Mar 10 2026](https://www.manton.org/2026/03/10/thomas-ricouard-is-joining-openai.html)

**Alexander Grebenyuk (kean) — author of Nuke, Pulse — "Claude Code Experience" (Jun 23, 2025)**
- Had passed on Cursor-style tools because he did not want another IDE; [snippet] "Claude Code works alongside Xcode and feels like a natural extension of my current workflow."; initially pay-per-token "where costs ramp up quickly", later [snippet] "upgraded to a Max monthly plan and started exploring without worrying about costs." — [kean.blog](https://kean.blog/post/experiencing-claude-code); markdown source [github.com/kean/articles](https://github.com/kean/articles/blob/main/2025-06-23-experiencing-claude-code.markdown)
- Michael Tsai's round-up adds the caveat that sending a private codebase to the cloud is a real trade-off. — [mjtsai.com, Jun 27 2025](https://mjtsai.com/blog/2025/06/27/claude-code-experience/)

**Christopher (Chris) Trott — twocentstudios (indie iOS dev since 2013, Vinylogue)**
- "Rewriting a 12 Year Old Objective-C iOS App with Claude Code" (Jun 22, 2025): ported Vinylogue (2013 Obj-C/UIKit/ReactiveCocoa) to Swift/SwiftUI; [snippet] "Using Claude Code to automate a lot of tedious work of porting the data models, dominant color algorithm, and data migration code left me with an unusual abundance of time and energy"; then migrated the whole codebase to Point-Free's modern SwiftUI architecture (swift-dependencies, swift-sharing); verdict: the $20 was worth it, but the tool is "still relatively unoptimized for Apple platforms development". A search excerpt attributed to this post: Claude "knew how to call xcodebuild without setup, but was very inconsistent on which build flags, simulators, OS versions, etc. it picked" (attribution moderately confident). — [twocentstudios.com](https://twocentstudios.com/2025/06/22/vinylogue-swift-rewrite/); repo [github.com/twocentstudios/vinylogue](https://github.com/twocentstudios/vinylogue)
- "Giving Claude Code Eyes to See Your SwiftUI Views" (Jul 13, 2025): a way to capture SwiftUI views directly from the simulator for Claude. — [twocentstudios.com](https://twocentstudios.com/2025/07/13/giving-claude-code-eyes-to-see-your-swiftui-views/)
- "Closing the Loop on iOS with Claude Code" (Dec 27, 2025): [snippet] "closing the loop means giving Claude Code a way to view the output of its work"; breaks the loop into building, installing/launching on the simulator, reading console output, controlling the simulator, and running on device; done over ~a month in Dec 2025 with Opus 4.5 in Claude Code v2.0.76 and Xcode 26.1/26.2. — [twocentstudios.com](https://twocentstudios.com/2025/12/27/closing-the-loop-on-ios-with-claude-code/); announcement [hachyderm.io](https://hachyderm.io/@twocentstudios/115806936660212927)

**Donny Wals — Swift author/educator — "Setting up a delivery pipeline for your agentic iOS projects" (2026)**
- Motivating case: a crash during a workout; he passed the crash report to an agent and came back to a PR he could review, merge and ship to TestFlight; keeps agents.md as a rulebook "that grows whenever an agent does something he doesn't want"; argues reviewing the plan before execution is where bad architecture gets caught; follow-up post covers FlowDeck, a CLI giving agents structured build errors and streamed logs; on the Empower Apps podcast he said SwiftData migrations are a place he still doesn't trust agents. — [donnywals.com](https://www.donnywals.com/setting-up-a-delivery-pipeline-for-your-agentic-ios-projects/); [Empower Apps podcast](https://podcasts.apple.com/us/podcast/empower-apps/id1437435392)

**Jacob Bartlett — Jacob's Tech Tavern; iOS at Granola**
- "Advanced Agentic Engineering" (Sep 2, 2026): has run several parallel agents daily for more than a year; [snippet] "automatic verification is the backbone of agent parallelism"; without self-checking a frontier model needs ~5-10 minutes per screen, with self-checking instructions sessions stretch to an hour or overnight. (Search results did not show him naming Claude Code specifically.) — [blog.jacobstechtavern.com](https://blog.jacobstechtavern.com/p/advanced-agentic-engineering)
- "2025: The year SwiftUI died": points agents at existing code (folder of past side projects) and logs review issues in AGENTS.md so mistakes don't recur, e.g. Swift 6.2 concurrency warnings. — [blog.jacobstechtavern.com](https://blog.jacobstechtavern.com/p/the-year-swiftui-died)
- "My Secret Plot to Kill SwiftUI": moved Granola's iOS architecture from SwiftUI to UIKit in about a week; AI chat screen as proof of concept for a possible agent-driven rebuild. — [blog.jacobstechtavern.com](https://blog.jacobstechtavern.com/p/my-secret-plot-to-kill-swiftui)

**Paul Hudson — Hacking with Swift**
- Released a SwiftUI agent skill ("a hands-on set of rules meant to help AI coding tools write better SwiftUI") and an AGENTS.md "encapsulating the essence of Paul Hudson and Hacking with Swift" for Claude Code/Codex ("Teach your AI to write Swift the Hacking with Swift way"). Promotional, not a critical workflow write-up. — [hackingwithswift.com](https://www.hackingwithswift.com/articles/284/teach-your-ai-to-write-swift-the-hacking-with-swift-way)

**Antoine van der Lee — SwiftLee, RocketSim**
- Maintains the SwiftUI Agent Skill (`swiftui-expert-skill`, Agent Skills format for Claude Code/Codex/Cursor) covering modern APIs, state management, performance, iOS 26 Liquid Glass; install via `/plugin marketplace add AvdLee/SwiftUI-Agent-Skill`; v5.1.0 added an iPhone Duo reference; companion Swift Concurrency Expert and Core Data Expert skills; demoed with RocketSim live simulator previews while the agent works. — [skills.sh/avdlee](https://skills.sh/avdlee/swiftui-agent-skill); [vibeindex listing](https://vibeindex.ai/marketplaces/AvdLee/SwiftUI-Agent-Skill); repo github.com/AvdLee/SwiftUI-Agent-Skill

**Rudrank Riyam — MusadoraKit author, ex-Apple intern, DevRel**
- Book/course "Exploring AI-Driven Coding for Apple Platforms Apps" aimed at improving Swift/SwiftUI/UIKit work with Claude Code and Codex; Claude Code chapters out (getting started; pointing Claude Code at other models), memory/tips chapters upcoming. — [academy.rudrank.com](https://academy.rudrank.com/product/ai-driven-coding)
- "Exploring Xcode Using MCP Tools" walkthrough of Apple's Xcode 26.3 MCP tools (documentation search, Swift REPL) is cited by Blake Crosley. — [blakecrosley.com](https://blakecrosley.com/blog/xcode-mcp-claude-code)
- Built a Go-based App Store Connect CLI (60+ commands) with Claude Code skills; a third party reports it replaced Fastlane for a TestFlight release. — [search summary; secondhand]

**Simon Willison (not an Apple dev, but widely read)** — "Vibe coding SwiftUI apps is a lot of fun"; reports recent Claude models handle SwiftUI well on macOS projects. — [simonw.substack.com](https://simonw.substack.com/p/vibe-coding-swiftui-apps-is-a-lot)

**Blake Crosley — "Building iOS Apps with AI Agents: The Practitioner's Guide" (Aug 2026), drawn from eight production iOS apps** (standing unverified; included as a practitioner synthesis): agents strong at SwiftUI views, SwiftData models and build-error diagnosis; weak at project-file edits, code signing and visual debugging; recommends Claude Code CLI + XcodeBuildMCP as "the most mature runtime with the deepest MCP tool coverage". — [blakecrosley.com guide](https://blakecrosley.com/guides/ios-agent-development); [Two MCP Servers Made Claude Code an iOS Build System](https://blakecrosley.com/blog/xcode-mcp-claude-code)

### Inferences
- The indie/senior consensus formed early (May-Jul 2025) and held: Claude Code's SwiftUI output is good, its Swift Concurrency output is unreliable, and the "closed loop" (build, run, screenshot, logs) is the determinant of success. Later posts (Trott Dec 2025, Wals 2026, Bartlett Sep 2026) are about engineering that loop rather than about whether to use the tool.
- Several of the strongest early advocates (Steinberger, Ricouard) later moved to OpenAI and/or Codex, so their 2025 praise of Claude Code should be dated; Steinberger's Oct 2025 post explicitly reverses his preference.

### Gaps
- Could not fetch primary pages for Karunaratne, Steinberger, Ricouard, kean, Trott, Wals or Bartlett; quotes are short search excerpts and need verification.
- No first-hand Claude Code accounts found for Christian Selig, Jordan Morgan (only a "The Skills Conundrum" article title on swiftjectivec.com), Sean Allen, Majid Jabrayilov, Matt Gallagher, Marco Arment/ATP, Sebastiaan de With, Ben Scheirman, Krzysztof Zabłocki, Noah Gilmore.
- The contents of Steinberger's "The Future of Vibe Coding" post and the full text of "Just Talk To It" were not retrievable.
- Conference talks (NSSpain, Swift Heroes, try! Swift, Deep Dish Swift 2025/2026) and podcast transcripts (ATP, Under the Radar, Stacktrace, Swift over Coffee) were not surfaced by searches.

---

## Key Question 2: What have company engineering teams published about agentic coding for their iOS/tvOS apps?

### Takeaway
Duolingo (iOS unit-test generation pipeline using Claude Code) and Shopify (React Native -> native Swift/Kotlin, Sep 2026, with the gated "Helix" agent workflow) are the only detailed, first-party engineering write-ups found. Spotify, Uber and Airbnb have company-level adoption/cost figures (mostly via Anthropic case studies, earnings calls or press); Netflix has no confirmed iOS Claude Code material; nothing was found on tvOS from any company.

### Cited Findings

**Duolingo — "How we built an automated unit test generation pipeline for iOS"**
- Pipeline: four components — local validation, a PR label that triggers test generation, a scheduled backfill job, and a PR Lifecycle Manager that auto-assigns reviewers, auto-heals CI failures and auto-closes stale PRs. — [blog.duolingo.com](https://blog.duolingo.com/ai-ios-unit-test-generation-pipeline/)
- Results: over ~17 weeks, 250 accepted PRs and ~85,000 lines of test code "almost entirely autonomously". — [blog.duolingo.com](https://blog.duolingo.com/ai-ios-unit-test-generation-pipeline/)
- Discovery phase: [snippet] "They spent a few weeks running Claude Code locally and analyzing every CI result. The goal was to answer two questions: Which files can LLMs test well, and what are the common failure modes?" Early batches: Batch 1 — 17 PRs, 8 merged (47%); Batch 2 — 40 PRs, 19 merged (48%). — [blog.duolingo.com](https://blog.duolingo.com/ai-ios-unit-test-generation-pipeline/)
- Top early failure modes: [snippet] "mock type mismatch, Swift 6 Sendable, SwiftTesting/XCTest mixing"; the team treated the framework mixing as a prompt problem and rewrote its LLM rules to be explicit about which framework to use and when. — [blog.duolingo.com](https://blog.duolingo.com/ai-ios-unit-test-generation-pipeline/)
- Agent abstraction: internal wrapper around Codex CLI and the Claude Code SDK; [snippet] "Switching agents is, in most cases, as simple as changing a single enum parameter." — [blog.duolingo.com](https://blog.duolingo.com/ai-ios-unit-test-generation-pipeline/)
- Third-party summary (unverified against primary): 76% of PRs passed CI on first attempt; core MVVM test coverage rose from 9% to 30%. — [ZenML LLMOps database](https://www.zenml.io/llmops-database/automated-unit-test-generation-pipeline-for-ios-using-llms)
- Related Duolingo posts: "Agentic Workflows: Scale AI Prompts Beyond Cursor" and "How we reduced manual regression tests by 70% using AI tools". — [blog.duolingo.com/agentic-workflows](https://blog.duolingo.com/agentic-workflows/); [blog.duolingo.com/reduced-regression-testing](https://blog.duolingo.com/reduced-regression-testing/)

**Shopify — back to native (Sep 10, 2026, Mustafa Ali) and the Shop app migration / Helix**
- Decision: dropping React Native for its major mobile apps and rebuilding in Swift and Kotlin because agents changed the cost of building twice; [snippet] "They say the math no longer holds." — [shopify.engineering/back-to-native](https://shopify.engineering/back-to-native); analysis [RedMonk, Sep 22 2026](https://redmonk.com/kholterhoff/2026/09/22/shopify-native/)
- Proof of concept: [snippet] "One engineer spent a week working with coding agents to migrate as much of the existing React Native app as possible into a native iOS app built with SwiftUI." The prototype "wasn't production-ready, but it reproduced enough of the app to make a close migration look feasible." — [shopify.engineering/back-to-native](https://shopify.engineering/back-to-native)
- Outcome: proof of concept to a fully rebuilt native app in the app stores in 12 weeks (greenfield rebuild, some screens cut); cold startup fell 23% on iOS and 50% on Android. — [shopify.engineering/shop-app-migration](https://shopify.engineering/shop-app-migration)
- Helix workflow: [snippet] "Helix reads the React Native code and proposes a sequence of checkpoints (small, ordered slices of work), which the engineer can review and approve in minutes... Each checkpoint must prove its behavior with tests, match the reference (React Native) app in a visual review, pass two adversarial code reviews, and get an engineer's approval before it's committed"; "Small checkpoints also fit in a small context window"; "the existing app serves as the spec." — [shopify.engineering/helix](https://shopify.engineering/helix); [shopify.engineering/shop-app-migration](https://shopify.engineering/shop-app-migration)
- Simulator bottleneck: [snippet] "Agentic control of simulators has been a bottleneck. We found ourselves constantly babysitting them as they couldn't reliably build, test, and iterate." Shopify is "developing a command-line interface that lets agents inspect app state and execute actions without relying on slow simulator interactions"; an internal debugging tool, Tardis, gives agents structured access to live native events, logs and state and captures parity screenshots/event windows from both app versions at named checkpoints. — [shopify.engineering/shop-app-migration](https://shopify.engineering/shop-app-migration)
- Which agent: Shopify's posts (as excerpted) do not name Claude Code specifically; an open-source reconstruction notes the original used Gemini for UI review. — [github.com/johnarks/helix-loop](https://github.com/johnarks/helix-loop); related Shopify post on harness design [Building an agentic harness that outlasts the model](https://shopify.engineering/building-an-agentic-harness-that-outlasts-the-model)

**Spotify**
- Anthropic case study: Spotify's Claude Agent SDK setup cut engineering time on complex migrations by up to 90%; 650+ monthly merges of agent-produced code into production (self-reported, vendor site). — [claude.com/customers/spotify](https://claude.com/customers/spotify)
- Earnings call (Feb 10, 2026) per Fast Company: [snippet] "An engineer at Spotify on their morning commute from Slack on their cellphone can tell Claude to fix a bug or add a new feature to the iOS app" and get a build back to merge. — [Fast Company](https://www.fastcompany.com/91493217/spotify-ai-coding-new-features-claude)
- NerdOut@Spotify ep. 33 "Ship Happens (When Agents Code)": background agents built on Fleet Management, "supercharged by Claude Code". — [open.spotify.com](https://open.spotify.com/episode/7tCsLykUtW0rTYhM0vBR6E)

**Uber**
- Reported: 5,000 engineers given Claude Code access in Dec 2025; usage 32% -> 63% of engineers by Feb 2026; annual AI budget exhausted by ~April 2026, Claude Code the main driver (origin partly Reddit/X; treat cautiously). — [x.com/aakashgupta](https://x.com/aakashgupta/status/2044235027383492803); [HN 47976415](https://news.ycombinator.com/item?id=47976415)
- Uber set usage caps on agentic tools including Cursor and Claude Code (Jun 3, 2026). — [simonwillison.net](https://simonwillison.net/2026/Jun/3/uber-caps-usage/)
- Uber's AIFX group "owns Claude Code and Minions", its background agent orchestration system (job listing); share of code changes from Uber's internal coding agent rose from <1% to 8% in a few months (ShiftMag). — [ShiftMag](https://shiftmag.dev/how-uber-engineers-use-ai-agents-8617/)

**Airbnb**
- Q1 2026 earnings: 60% of code produced by engineers in the quarter was written by AI (company-wide, not mobile-specific). — [TechCrunch, May 8 2026](https://techcrunch.com/2026/05/08/airbnb-says-ai-now-writes-60-of-its-new-code/)
- DX session: PR throughput up ~65%; developers spending 4+ hours/day with agentic AI "dramatically increased their output"; internal tooling branded AirChat (CLI, SDK, Remote). — [getdx.com](https://getdx.com/podcast/beyond-the-cli-agentic-ai-for-async-workloads-and-non-developers/)
- No Airbnb post about iOS work with Claude Code was found; "Airbnb-style" Claude skills on marketplaces are third-party.

**Netflix**
- A reported CLAUDE.md "leak" bundled in the Netflix iOS app is unconfirmed; a July 2026 update says the circulating file came from a Python Metaflow extensions monorepo, not the app. — [nowrap.ai](https://nowrap.ai/news/netflix-claude-md-leak)
- Nov 2025 Anthropic webinar on scaling agent development at Netflix across 3,000+ developers (Claude Sonnet 4.5); nothing tvOS-specific. — [anthropic.com webinar](https://www.anthropic.com/webinars/scaling-ai-agent-development-at-netflix)

**Lyft** — Feb 2025 Anthropic partnership began with customer-service; "first phase of a broader collaboration... to build software internally"; no 2026 mobile/agent material found. — [TechCrunch, Feb 6 2025](https://techcrunch.com/2025/02/06/lyfts-new-ai-customer-assistant-is-powered-by-anthropics-claude)

**Platform vendor context**
- Anthropic "Claude in Xcode" (Xcode 26.3, Feb 2026): native integration with the Claude Agent SDK ("the same underlying harness that powers Claude Code"), with subagents, background tasks and plugins inside Xcode; Claude "can capture Xcode Previews to see what the interface it's building looks like in practice... and iterate from there." — [anthropic.com](https://www.anthropic.com/news/apple-xcode-claude-agent-sdk); [support.claude.com](https://support.claude.com/en/articles/12293051-using-claude-in-xcode)
- Claude Code Desktop (macOS) iOS Simulator pane, public beta (reported Jul 21, 2026 and Sep 10, 2026): Claude can open and interact with in-progress apps in a simulator pane beside the chat; requires Xcode + iOS platform. — [9to5Mac](https://9to5mac.com/2026/07/21/claude-code-brings-live-ios-app-testing-into-its-mac-app/); [iClarified](https://www.iclarified.com/101541/claude-code-now-works-with-apples-ios-simulator)
- Adoption signal: in the May 2026 window, 33,098 PRs in public GitHub Swift repos carried an agent mark = 30.7% of all Swift PRs; "Claude Code does the most of it" (index in preview). — [amplifying.ai](https://amplifying.ai/coding-agents/segments/swift)

### Inferences
- Both detailed company write-ups converge on the same control structure: small units of work (a file to test; a checkpoint of a screen) gated by automated verification plus human sign-off, with agent-neutral wrappers so the model can be swapped.
- Shopify's simulator complaint (Sep 2026) and Anthropic's simulator pane (Jul-Sep 2026) suggest "agent can drive the simulator" was the unsolved bottleneck for most of this period.

### Gaps
- No company (Netflix, Spotify, others) published anything tvOS-specific about agentic coding.
- Shopify's exact agent/model mix for Helix is not stated in the excerpts available.
- Duolingo post date not captured; the 76% first-attempt CI figure is from a third-party summary.

---

## Key Question 3: What recurring workflow patterns emerge?

### Takeaway
The dominant pattern is "close the loop": give the agent build, install/launch, console-log and screenshot access (via xcodebuild/simctl scripts, XcodeBuildMCP, Apple's Xcode MCP, Peekaboo, FlowDeck, RocketSim, or the Claude Code simulator pane) and keep Xcode open for the human. Other recurring patterns: a CLAUDE.md/AGENTS.md rulebook that grows from review findings; a docs/ folder of curated API guidance; plan-first review; small gated checkpoints; parallel agents; and agent-written release scripts.

### Cited Findings
- **Build-then-observe loop:** Trott's five-stage loop (build, install/launch, console, simulator control, device) and his earlier "eyes" post capturing SwiftUI views from the simulator. — [twocentstudios Dec 27 2025](https://twocentstudios.com/2025/12/27/closing-the-loop-on-ios-with-claude-code/); [Jul 13 2025](https://twocentstudios.com/2025/07/13/giving-claude-code-eyes-to-see-your-swiftui-views/)
- **Screenshots into the session:** Karunaratne took over to interact with UI and dropped screenshots of problems (no Playwright equivalent, Jul 2025). — [Simon Willison](https://simonwillison.net/2025/Jul/6/macos-app-built-entirely-by-claude-code/)
- **Claude Code beside Xcode:** kean: "works alongside Xcode and feels like a natural extension of my current workflow." — [kean.blog](https://kean.blog/post/experiencing-claude-code)
- **MCP build tooling:** Crosley adds XcodeBuildMCP and Apple's Xcode 26.3 MCP to Claude Code so the agent works from exact error positions and per-test results instead of raw logs; Karunaratne reportedly adopted XcodeBuildMCP after xcodebuild misuse. — [blakecrosley.com](https://blakecrosley.com/blog/xcode-mcp-claude-code); gist with a Claude Code + XcodeBuildMCP setup prompt [gist.github.com/joelklabo](https://gist.github.com/joelklabo/6df9fa603bec3478dec7efc17ea44596)
- **Structured build output CLI:** Wals' FlowDeck returns structured build errors and streams logs to agents. — [donnywals.com](https://www.donnywals.com/setting-up-a-delivery-pipeline-for-your-agentic-ios-projects/)
- **GUI automation/screenshots for agents:** Steinberger's Peekaboo. — [github.com/steipete/Peekaboo](https://github.com/steipete/Peekaboo)
- **Rulebook files:** Wals' agents.md grows with every unwanted agent behaviour; Bartlett logs review issues (e.g. Swift 6.2 concurrency warnings) in AGENTS.md; Karunaratne's CLAUDE.md pins SwiftUI-first, modern macOS APIs, Swift 6 async/await/actors. — [donnywals.com](https://www.donnywals.com/setting-up-a-delivery-pipeline-for-your-agentic-ios-projects/); [Bartlett](https://blog.jacobstechtavern.com/p/the-year-swiftui-died); [indragie.com](https://www.indragie.com/blog/i-shipped-a-macos-app-built-entirely-by-claude-code)
- **Curated docs folder:** Steinberger's swift-concurrency.md placed in docs/ and referenced from CLAUDE.md. — [x.com/steipete](https://x.com/steipete/status/1937816669075689840)
- **Published skills as shared context:** Hudson's SwiftUI skill/AGENTS.md; van der Lee's SwiftUI/Concurrency/Core Data expert skills. — [hackingwithswift.com](https://www.hackingwithswift.com/articles/284/teach-your-ai-to-write-swift-the-hacking-with-swift-way); [skills.sh/avdlee](https://skills.sh/avdlee/swiftui-agent-skill)
- **Plan review before execution:** Wals: reviewing the plan is where bad architecture gets caught. — [donnywals.com](https://www.donnywals.com/setting-up-a-delivery-pipeline-for-your-agentic-ios-projects/)
- **"Give me options" prompting:** Steinberger. — [x.com/steipete](https://x.com/steipete/status/1937184376657265077)
- **Small gated checkpoints with tests + visual parity + adversarial reviews + human approval:** Shopify Helix. — [shopify.engineering/helix](https://shopify.engineering/helix)
- **Tests-first / test generation at scale with local validation before automation:** Duolingo. — [blog.duolingo.com](https://blog.duolingo.com/ai-ios-unit-test-generation-pipeline/)
- **Parallel agents:** Steinberger's 3-8 agents in one folder with per-agent atomic commits; Bartlett's verification-driven parallelism; Anthropic's Boris Cherny runs five terminals each on its own git worktree (general, not Apple-specific). — [steipete.me](https://steipete.me/posts/just-talk-to-it); [Bartlett](https://blog.jacobstechtavern.com/p/advanced-agentic-engineering); [vibecoder blog on Cherny](https://blog.vibecoder.me/multi-claude-parallel-agents-anthropic-workflow)
- **Migrations:** Trott (Obj-C/UIKit -> Swift/SwiftUI, then to Point-Free architecture); Steinberger (700+ tests XCTest -> Swift Testing); Shopify (RN -> SwiftUI, "existing app serves as the spec"); Bartlett (SwiftUI -> UIKit at Granola in ~a week). — sources as above
- **Crash triage:** Wals hands a crash report to an agent and reviews the resulting PR. — [donnywals.com](https://www.donnywals.com/setting-up-a-delivery-pipeline-for-your-agentic-ios-projects/)
- **Release automation:** Karunaratne's agent-written build/sign/notarize/Sparkle/GitHub release script; Steinberger's notarization war stories. — [x.com/indragie](https://x.com/indragie/status/1938055943130124379); [steipete.me](https://steipete.me/posts/2025/code-signing-and-notarization-sparkle-and-tears)
- **Checkpoint/rewind:** a practitioner notes Claude Code's checkpoint feature ("press Escape twice and rewind"). — [johnrodrigues.substack.com](https://johnrodrigues.substack.com/p/building-an-ios-app-with-claude-code)
- **.pbxproj handling:** no elite first-hand account found; third-party templates route Xcode project changes through an XcodeGen spec rather than editing the project file, and Tuist's Mar 21, 2025 post explains why group/file references cause conflicts and suggests `*.pbxproj merge=union` with caveats. — [tuist.dev](https://tuist.dev/blog/2025/03/21/git-conflicts); [thepromptshelf template](https://thepromptshelf.dev/blog/claude-code-swift-ios-xcode-guide-2026/)
- **Remote/mobile triggering:** Spotify engineers kick off iOS changes from Slack on a phone. — [Fast Company](https://www.fastcompany.com/91493217/spotify-ai-coding-new-features-claude)

### Inferences
- "Modular SPM architecture to shrink context" was not explicitly claimed by any named practitioner found; the closest evidence is Shopify's "small checkpoints fit a small context window" and Karunaratne's emphasis on context management. Treat SPM-modularisation-for-agents as plausible but unsourced here.
- Localization and accessibility workflows with Claude Code were not discussed by any of the sources found.

### Gaps
- No first-hand accounts specifically on localization, accessibility, or tvOS focus-engine work with Claude Code.
- No named practitioner discussed .pbxproj churn strategies in the retrievable material.

---

## Key Question 4: What does Claude Code get wrong for Swift, and how do practitioners mitigate it?

### Takeaway
Reported weaknesses cluster around Swift Concurrency / Swift 6 strict concurrency (Sendable errors, missing @MainActor hops), reaching for legacy Objective-C/AppKit/UIKit APIs, SwiftUI type-checker timeouts, inconsistent xcodebuild flags/simulator selection, mixing Swift Testing with XCTest, Xcode project-file edits, code signing/entitlements, and visual debugging. Mitigations: curated concurrency docs and skills, explicit CLAUDE.md API/version pins, "build must succeed" gates, MCP build tools, screenshots/simulator access, and prompt rules about test frameworks.

### Cited Findings
- **Swift Concurrency weakness:** Karunaratne (Jul 2025) — struggles with Swift 5.5+ concurrency; falls back to Objective-C APIs. — [heise.de](https://www.heise.de/en/news/When-AI-programs-a-Mac-app-Developer-reports-on-experiences-10480791.html); [indragie.com](https://www.indragie.com/blog/i-shipped-a-macos-app-built-entirely-by-claude-code)
- **Swift 6 Sendable errors in generated tests:** Duolingo lists "Swift 6 Sendable" among top failure modes. — [blog.duolingo.com](https://blog.duolingo.com/ai-ios-unit-test-generation-pipeline/)
- **Runtime-only main-actor bugs:** a guide author has seen Claude write async code that changes published state without hopping to the main actor, surfacing only as a runtime warning; and `Task { }` inside `.onAppear` instead of `.task`, which leaks if the view disappears. — [claudify.tech](https://claudify.tech/blog/claude-code-swift) (third-party guide; lower authority)
- **SwiftUI type-checker timeouts:** recovered by splitting view bodies into smaller expressions. — [Simon Willison](https://simonwillison.net/2025/Jul/6/macos-app-built-entirely-by-claude-code/)
- **xcodebuild inconsistency:** "very inconsistent on which build flags, simulators, OS versions, etc. it picked". — [twocentstudios (attribution moderately confident)](https://twocentstudios.com/2025/06/22/vinylogue-swift-rewrite/)
- **Test framework mixing:** "SwiftTesting/XCTest mixing" — fixed by explicit prompt rules. — [blog.duolingo.com](https://blog.duolingo.com/ai-ios-unit-test-generation-pipeline/)
- **Xcode project files, signing, visual debugging:** Crosley: weak at "project-file edits, code signing, and visual debugging"; a classmethod.jp write-up: the AI "struggled with aspects such as editing Xcode project files", pushing to an "AI-led + human support" approach. — [blakecrosley.com](https://blakecrosley.com/guides/ios-agent-development); [dev.classmethod.jp](https://dev.classmethod.jp/en/articles/claude-code-ios-app-development-ai-only/)
- **AppKit escape hatches and distribution:** Steinberger needed AppKit for menu-bar popover/settings, and found signing/notarization/Sparkle-in-sandbox harder than the code. — [steipete.me](https://steipete.me/posts/2025/code-signing-and-notarization-sparkle-and-tears)
- **SwiftData migrations:** Wals still does not trust agents there. — [Empower Apps podcast](https://podcasts.apple.com/us/podcast/empower-apps/id1437435392)
- **Deprecated/inefficient SwiftUI in AI output (claim, unsourced figure):** AppVerticals asserts AI SwiftUI often uses deprecated APIs and "35% of such code needs refactoring" — no source given; treat as marketing. — [appverticals.com](https://www.appverticals.com/blog/build-an-ios-app-with-claude-code/)
- **Hallucinated SwiftUI modifiers:** no source documenting this specifically was found.
- **Mitigation — concurrency doc:** Steinberger's agent-rules/docs/swift-concurrency.md referenced from CLAUDE.md. — [x.com/steipete](https://x.com/steipete/status/1937816669075689840)
- **Mitigation — skills:** van der Lee's Swift Concurrency Expert / SwiftUI Expert skills; Hudson's SwiftUI skill. — [skills.sh/avdlee](https://skills.sh/avdlee/swiftui-agent-skill); [hackingwithswift.com](https://www.hackingwithswift.com/articles/284/teach-your-ai-to-write-swift-the-hacking-with-swift-way)
- **Mitigation — CLAUDE.md pins:** templates pin deployment target/Xcode version, forbid `if #available` unless older OS support is required, name the navigation container (NavigationStack vs NavigationSplitView), forbid deprecated NavigationView, and require "xcodebuild must succeed for every supported platform target before the work is considered complete". — [thepromptshelf.dev](https://thepromptshelf.dev/blog/claude-code-swift-ios-xcode-guide-2026/); [claudify.tech](https://claudify.tech/blog/claude-code-swift) (third-party templates)
- **Mitigation — rulebook from review findings:** Wals and Bartlett (above).
- **Mitigation — MCP tooling / simulator access:** XcodeBuildMCP, Xcode MCP, Claude Code simulator pane, Peekaboo, FlowDeck (above).
- **Mitigation — agent wrapper + explicit framework rules:** Duolingo (above).

### Inferences
- The failure list is stable from mid-2025 to 2026; what changed is tooling (Xcode 26.3 Previews capture, simulator pane), which attacks the "visual debugging" weakness rather than the concurrency weakness.

### Gaps
- No practitioner quantified error rates for concurrency or API-hallucination issues; Duolingo is the only source with failure-mode counts, and those are for generated tests.
- Info.plist/entitlements errors were not specifically discussed except via Steinberger's Sparkle sandbox entitlement story.

---

## Key Question 5: Quantitative claims (with source and context)

### Takeaway
Most numbers are self-reported and context-specific: a solo macOS app at ~20k LOC with <1k hand-written (Karunaratne); ~47k LOC Swift at 92% coverage (Steinberger's Vibe Meter); 250 PRs / ~85k lines of tests in 17 weeks with 47-48% early merge rates (Duolingo); 1 engineer, 1 week PoC and 12 weeks to App Store (Shopify); up to 90% migration-time reduction and 650+ monthly agent merges (Spotify via Anthropic); 60% of new code AI-written (Airbnb, company-wide); 30.7% of public Swift PRs agent-marked (amplifying.ai, May 2026).

### Cited Findings
- ~20,000 LOC, <1,000 hand-written; "$200 a month" Max plan ~ "an extra 5 hours every day" (Karunaratne, Jul 2025). — [Simon Willison](https://simonwillison.net/2025/Jul/6/macos-app-built-entirely-by-claude-code/)
- Vibe Meter: ~3 days to first release; ~47,000 lines of Swift, 92% test coverage (Steinberger, 2025). — [steipete.me](https://steipete.me/posts/2025/vibe-meter-monitor-your-ai-costs)
- ~1 hour/day saved by disabling permission prompts; 2 months without damage (Steinberger, Jun 2025). — [steipete.me](https://steipete.me/posts/2025/claude-code-is-my-computer)
- 700+ tests migrated XCTest -> Swift Testing with AI (Steinberger, Jun 2025). — [steipete.me/posts](https://steipete.me/posts)
- 3-8 parallel agents; Codex ~230k vs Claude 156k usable context (Steinberger, ~Oct 2025). — [steipete.me](https://steipete.me/posts/just-talk-to-it)
- "$20 was worth it" for the Vinylogue rewrite (Trott, Jun 2025). — [twocentstudios.com](https://twocentstudios.com/2025/06/22/vinylogue-swift-rewrite/)
- 5-10 min per screen unverified vs 1 hour/overnight sessions with self-verification (Bartlett, Sep 2026). — [blog.jacobstechtavern.com](https://blog.jacobstechtavern.com/p/advanced-agentic-engineering)
- Duolingo: 17 weeks, 250 accepted PRs, ~85,000 lines; batch merge rates 47% (8/17) and 48% (19/40); third-party: 76% first-attempt CI pass, MVVM coverage 9% -> 30%. — [blog.duolingo.com](https://blog.duolingo.com/ai-ios-unit-test-generation-pipeline/); [ZenML](https://www.zenml.io/llmops-database/automated-unit-test-generation-pipeline-for-ios-using-llms)
- Shopify: 1 engineer/1 week PoC; 12 weeks PoC -> store; cold start -23% iOS, -50% Android; Android binary -109 MB. — [shopify.engineering/shop-app-migration](https://shopify.engineering/shop-app-migration)
- Spotify: up to 90% less engineering time on complex migrations; 650+ monthly merges (vendor case study). — [claude.com/customers/spotify](https://claude.com/customers/spotify)
- Uber: 32% -> 63% engineer usage; budget exhausted in ~4 months; internal agent share of code changes <1% -> 8%. — [x.com/aakashgupta](https://x.com/aakashgupta/status/2044235027383492803); [ShiftMag](https://shiftmag.dev/how-uber-engineers-use-ai-agents-8617/)
- Airbnb: 60% of new code AI-written (Q1 2026); PR throughput +65%. — [TechCrunch](https://techcrunch.com/2026/05/08/airbnb-says-ai-now-writes-60-of-its-new-code/); [getdx.com](https://getdx.com/podcast/beyond-the-cli-agentic-ai-for-async-workloads-and-non-developers/)
- 30.7% of public Swift PRs (33,098) agent-marked in May 2026; Claude Code the largest share. — [amplifying.ai](https://amplifying.ai/coding-agents/segments/swift)
- Unsupported headline claims to discount: "Reduce iOS Development Time by 60% with Claude Code" (Medium, no evidence in excerpt); "35% of AI SwiftUI code needs refactoring" (AppVerticals, no source). — [medium.com/@osmandemiroz](https://medium.com/@osmandemiroz/reduce-ios-development-time-by-60-with-claude-code-86a4e9d864ca); [appverticals.com](https://www.appverticals.com/blog/build-an-ios-app-with-claude-code/)

### Inferences
- No practitioner published token counts or cost-per-feature for Apple work; the only cost signals are subscription tiers ($20 Pro, $200 Max) and Steinberger's Vibe Meter tool for estimating spend.

### Gaps
- No bug-rate or defect-density data for agent-written Swift from any named practitioner or company.

---

## Key Question 6: Anti-patterns and regrets reported

### Takeaway
Reported anti-patterns are mostly process-level: running without feedback loops, trusting auto-compaction, babysitting simulators, letting the rulebook stagnate, skipping plan review, and over-relying on hooks as guardrails. Explicit "regret" statements are rare; the clearest reversals are Steinberger abandoning Claude Code for Codex (Oct 2025) and the warnings about privacy and prompt-injection risk when running with permissions disabled.

### Cited Findings
- **Context rot / compaction:** Karunaratne — auto-compaction "can miss important details or carry forward low-quality context from earlier mistakes". — [indragie.com (via search summary)](https://www.indragie.com/blog/i-shipped-a-macos-app-built-entirely-by-claude-code)
- **Unreliability before context fills:** Steinberger — Claude "gets unreliable well before it fills its window". — [steipete.me](https://steipete.me/posts/just-talk-to-it)
- **Hooks are not guardrails:** Steinberger — "models will get around a hook if they're determined to". — [steipete.me](https://steipete.me/posts/just-talk-to-it)
- **Permission-free mode risk:** HN commenter on Steinberger's post warned about prompt injection leaking API keys/credentials. — [news.ycombinator.com](https://news.ycombinator.com/item?id=44170967)
- **Privacy trade-off:** Michael Tsai on kean's post — sending a private codebase to the cloud is a real trade-off. — [mjtsai.com](https://mjtsai.com/blog/2025/06/27/claude-code-experience/)
- **Simulator babysitting:** Shopify — "constantly babysitting them as they couldn't reliably build, test, and iterate." — [shopify.engineering/shop-app-migration](https://shopify.engineering/shop-app-migration)
- **Unreviewed output:** Medium "MVP for Untitled tvOS App" built in Claude Code Web — 21 milestones in ~30 minutes, "the code wasn't reviewed closely" (illustrates the review-skipping anti-pattern; author not an elite practitioner). — [medium.com/@rizwanm](https://medium.com/@rizwanm/mvp-for-untitled-tvos-app-ba291e8813ec)
- **Not a replacement for knowing Swift:** a Medium author stresses Claude Code "doesn't replace knowing Swift or Apple's UI frameworks"; developers "either treat it as fancy autocomplete or avoid it entirely". — [medium.com/codetodeploy](https://medium.com/codetodeploy/10-tips-to-maximize-claude-code-for-ios-development-29027edc51a7)
- **Legacy API drift:** repeated fallback to Objective-C/AppKit/UIKit even when SwiftUI/modern Swift exists (Karunaratne). — [heise.de](https://www.heise.de/en/news/When-AI-programs-a-Mac-app-Developer-reports-on-experiences-10480791.html)
- **Tool switching / vendor volatility:** Steinberger's Oct 2025 reversal to Codex; Duolingo's enum-switchable agent wrapper as a hedge. — [steipete.me](https://steipete.me/posts/just-talk-to-it); [blog.duolingo.com](https://blog.duolingo.com/ai-ios-unit-test-generation-pipeline/)
- **Terminal UX limits:** Karunaratne doubts a terminal will be the ideal UX. — [x.com/indragie](https://x.com/indragie/status/1945293451668369509)

### Inferences
- "Test gaming" and "architecture drift" were not named by any source found; Shopify's two adversarial reviewers plus visual parity and Wals' plan-first review are implicit defences against both.
- Review fatigue is implied by Duolingo's need for a PR Lifecycle Manager (auto-assign, auto-heal, auto-close) but not stated as a complaint.

### Gaps
- No practitioner explicitly reported regret over over-reliance, review fatigue, architecture drift, or test gaming in the retrievable material.

---

## tvOS-specific note (cross-cutting gap)
- No first-hand account from a notable engineer or company about using Claude Code for tvOS was found. Available material is limited to: Claude Code skills for the tvOS focus engine (noting tvOS uses a geometric focus engine and that `.disabled()` "breaks tvOS navigation entirely") — [mcpmarket tvOS focus skill](https://mcpmarket.com/tools/skills/tvos-focus-engine-assistant); [Crosley tvOS focus patterns](https://blakecrosley.com/blog/tvos-focus-engine-swiftui); Showmax's (pre-Claude) SwiftUI-on-tvOS focus struggles — [showmax.engineering](https://showmax.engineering/articles/our-experience-with-swiftui-on-tvos); the TVFocusKit package — [github.com/CreatureSurvive/TVFocusKit](https://github.com/CreatureSurvive/TVFocusKit); a Pulpo PR adding a native tvOS 26 app from a `claude/`-prefixed branch — [github.com/IsaacThoman/pulpo PR 776](https://github.com/IsaacThoman/pulpo/pull/776); and the unreviewed Claude Code Web tvOS MVP above.

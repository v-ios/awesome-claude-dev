---
name: release-check
description: Walk the iOS/tvOS release checklist (version and build bump, changelog, archive/export options, signing items that need a human) and stop before anything is uploaded. Human-triggered only.
argument-hint: "<marketing-version> [build-number]"
disable-model-invocation: true
allowed-tools: Bash(agvtool what-version *), Bash(agvtool what-marketing-version *), Bash(git log *), Bash(git diff *), Bash(git status *), Bash(git tag *), Bash(scripts/xcb.sh *), Bash(scripts/arch-check.sh *), Read, Grep, Glob
---

<!-- composed: not from official docs; `disable-model-invocation: true` for side-effecting workflows and the agvtool injection are from the skills docs and the composed release-checklist skill in research/notes/governance_and_context_engineering.md KQ5; the "stop before upload / signing needs a human" policy is from ios-template's AGENTS.md. -->

## Current versions

Build (`agvtool what-version -terse`): !`agvtool what-version -terse 2>/dev/null || echo "agvtool unavailable (set CURRENT_PROJECT_VERSION / run on macOS)"`
Marketing (`agvtool what-marketing-version -terse1`): !`agvtool what-marketing-version -terse1 2>/dev/null || echo "unavailable"`
Last tag: !`git describe --tags --abbrev=0 2>/dev/null || echo "none"`

## Checklist (report each item as DONE / TODO / NEEDS HUMAN)

Target: marketing version `$0`, build `$1` (if omitted, propose last build + 1).

1. **Branch state** — `git status` clean except the release edits; `git log <last-tag>..HEAD --oneline` reviewed.
2. **Gates green** — `scripts/xcb.sh test ios`, `scripts/xcb.sh test tvos` (or confirm the CI run for this SHA is
   green: `ci/ios-guardrails.yml`), `scripts/arch-check.sh`. Never skip the tvOS build for a shared code base.
3. **Changelog** — `CHANGELOG.md` has a `## [<version>] - <date>` section moved from `[Unreleased]` with
   user-facing entries (Added/Changed/Fixed) for both platforms; App Store "What's New" text drafted from it.
4. **Version/build bump** — propose the exact commands and WAIT for approval (they are `ask` rules):
   `agvtool new-marketing-version <version>` and `agvtool new-version -all <build>` (or edit `MARKETING_VERSION`
   / `CURRENT_PROJECT_VERSION` in the `.xcconfig` if the project uses xcconfig-driven versions). Never edit
   `Info.plist` version keys by hand; iOS and tvOS targets must end up on the same marketing version.
5. **Archive/export plist review** — `ExportOptions.plist` (or the CI equivalent) has `method` (`app-store-connect`
   / `release-testing`), `teamID`, `signingStyle`, `uploadSymbols: true`, `destination`; confirm per-target
   `provisioningProfiles` when manual signing. `scripts/xcb.sh` builds simulators only — `xcodebuild archive`
   and `-exportArchive` are `ask` rules; propose the command, do not run it unasked.
6. **Signing (NEEDS HUMAN, always)** — certificate expiry, provisioning profiles for app + extensions (Top Shelf,
   widgets), entitlements diff since last release (`git diff <last-tag>..HEAD -- '*.entitlements'`), App Groups,
   push environment. Report, never edit (`protect-files.sh` blocks it anyway).
7. **Store assets** — screenshots for iPhone and Apple TV sizes, privacy nutrition labels for new SDKs/APIs,
   `PrivacyInfo.xcprivacy` reasons, age rating unchanged, tvOS Top Shelf image updated if the layout changed.
8. **Dependencies** — `Package.resolved`/`Podfile.lock` unchanged since the approved bump; third-party SDK
   versions listed in the release notes.
9. **STOP** — tagging (`git tag`), pushing, `xcrun altool`/`notarytool`, TestFlight/App Store upload and
   `fastlane` runs need explicit human approval. End with the summary below and wait.

## Summary format

```
Release <version> (<build>) — iOS + tvOS
DONE: ...
TODO (I can do): ...
NEEDS HUMAN: signing/profile checks, upload, tag push
Proposed commands (not run): agvtool ..., xcodebuild archive ..., git tag ...
```

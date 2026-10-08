# Contributing

This repository collects research and a copy-in playbook for using Claude Code on native iOS and tvOS projects.

## What belongs here

- **Research** (`research/`): evidence-backed notes and the synthesized report. Every claim needs a URL and an evidence tag (`[Official]`, `[Source]`, `[Snippet]`, `[Secondhand]`, `[Inference]`), matching the convention in `research/report.md`.
- **Playbook** (`playbook/`): files meant to be copied into an app repository (`CLAUDE.md`, `.claude/rules`, hooks, skills, subagents, scripts, CI). Anything composed rather than copied from official documentation must carry a `composed:` marker so adopters know to validate it.

## How to contribute

1. Open an issue describing the practice, tool, or correction, with the source link.
2. For playbook changes, state which Claude Code version and Xcode version you validated against.
3. Keep shell scripts `bash -n` clean and `set -euo pipefail`; keep JSON valid (no comments) and YAML parseable.
4. Do not add tools that cannot prove they parse Swift and Objective-C; see the evaluation method in `research/report.md` (Part 2) and `playbook/scripts/eval-context-tool.sh`.

## Review checklist for pull requests

- Sources linked and dated (Claude Code and Xcode change monthly).
- No secrets, bundle identifiers, or team-specific scheme names outside the documented placeholders.
- Markdown links resolve inside the repository.

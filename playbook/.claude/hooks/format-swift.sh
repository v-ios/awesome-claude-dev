#!/usr/bin/env bash
# .claude/hooks/format-swift.sh — PostToolUse hook for Edit|Write|MultiEdit.
# For the one .swift file that was just touched: swiftformat, then `swiftlint --fix`, then `swiftlint lint`.
# Lint violations go to stderr with exit 2 — per the ios-template rationale quoted in
# research/notes/governance_and_context_engineering.md KQ3: "Claude Code feeds a PostToolUse hook's stderr back
# to the agent only on exit 2 — the failure is reported to whoever made the edit instead of being silenced".
# (Exit 2 does not undo the edit; PostToolUse cannot block. It makes Claude see and fix the violations.)
#
# Single-file invocation: SwiftLint's README documents --fix/--strict/--config but not `lint <path>` explicitly
# (noted as a gap in the research); positional paths work on current SwiftLint — verify once with
#   swiftlint lint --quiet Sources/SomeFile.swift
# composed: the orchestration (format -> fix -> lint on one file) is this playbook's own; validate in your repo.
# Runs from $CLAUDE_PROJECT_DIR so .swiftformat and .swiftlint.yml apply. Nothing else in the tree is touched.
# Missing tools are reported but do not fail the edit (install them: brew install swiftformat swiftlint).
set -euo pipefail

INPUT="$(cat)"

json_get() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r --arg p "$1" 'getpath($p | split(".")) // empty | if type == "string" then . else tostring end' 2>/dev/null || true
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python3 -I -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for k in sys.argv[1].split("."):
    d = d.get(k) if isinstance(d, dict) else None
    if d is None:
        sys.exit(0)
print(d if isinstance(d, str) else json.dumps(d))' "$1" 2>/dev/null || true
  fi
}

FILE="$(json_get tool_input.file_path)"
[[ -n "$FILE" ]] || exit 0
FILE="${FILE//\\//}"
case "$FILE" in *.swift) ;; *) exit 0 ;; esac
[[ -f "$FILE" ]] || exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$ROOT" || exit 0

# Resolve symlinks/relative segments and refuse files outside the project (same guard as ios-template).
DIR="$(cd "$(dirname "$FILE")" 2>/dev/null && pwd -P)" || exit 0
RESOLVED="$DIR/$(basename "$FILE")"
ROOT_P="$(pwd -P)"
case "$RESOLVED" in "$ROOT_P"/*) ;; *) exit 0 ;; esac
REL="${RESOLVED#"$ROOT_P"/}"

# Never reformat generated or vendored code
case "$REL" in
  .build/*|.derivedData/*|DerivedData/*|build/*|Pods/*|*/Generated/*|.claude/worktrees/*) exit 0 ;;
esac

if ! command -v swiftformat >/dev/null 2>&1; then
  echo "format-swift.sh: swiftformat not installed (brew install swiftformat); skipped formatting $REL" >&2
else
  if ! out="$(swiftformat "$RESOLVED" --quiet 2>&1)"; then
    echo "swiftformat could not format $REL:" >&2
    printf '%s\n' "$out" | tail -n 5 >&2
    echo "Fix the syntax error, then run: swiftformat $REL" >&2
    exit 2
  fi
fi

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "format-swift.sh: swiftlint not installed (brew install swiftlint); skipped linting $REL" >&2
  exit 0
fi

swiftlint --fix --quiet "$RESOLVED" >/dev/null 2>&1 || true
if ! lint_out="$(swiftlint lint --quiet "$RESOLVED" 2>&1)"; then
  echo "SwiftLint violations in $REL (strict: warnings fail). Fix the code; do NOT add // swiftlint:disable (needs human sign-off):" >&2
  printf '%s\n' "$lint_out" | head -n 40 >&2
  exit 2
fi
exit 0

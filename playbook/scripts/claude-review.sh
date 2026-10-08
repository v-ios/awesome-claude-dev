#!/usr/bin/env bash
# scripts/claude-review.sh — headless `claude -p` review of `git diff <base>...HEAD`, usable locally and in CI.
#
# CLI flags are the documented headless ones (research/notes/governance_and_context_engineering.md KQ9,
# daily_workflows_and_sessions.md KQ1): -p, --output-format json, --json-schema, --max-turns, --max-budget-usd,
# --permission-mode dontAsk, --allowedTools, --append-system-prompt, --model, --bare, --no-session-persistence,
# and piping the diff on stdin so Claude needs no Bash permission to read it.
# composed: the orchestration, the JSON schema and the Markdown rendering are this script's own; validate in your repo.
#
# Usage:
#   scripts/claude-review.sh [--base REF] [--out DIR] [--max-turns N] [--max-budget-usd X] [--model M]
#                            [--bare] [--fail-on blocking|important|none] [--guidelines FILE]
#     --base REF        merge base to diff against (default: $REVIEW_BASE or origin/main, falling back to main)
#     --out DIR         where review.json and review.md are written (default: build/review)
#     --fail-on LEVEL   exit 1 when a finding at or above LEVEL exists (default: blocking)
#     --guidelines FILE review guidelines appended to the system prompt (default: REVIEW.md if present)
#     --bare            `claude --bare`: skips hooks/skills/MCP/CLAUDE.md; needs ANTHROPIC_API_KEY (recommended for CI)
#
# Outputs: <out>/review.json (full claude JSON incl. total_cost_usd, session_id, structured_output)
#          <out>/review.md   (severity-tagged findings, blocking first)
# Portable: runs anywhere `claude` and `git` run; no macOS guard needed (no Xcode calls).
set -euo pipefail

usage() {
  sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-1}"
}

BASE="${REVIEW_BASE:-}"
OUT="build/review"
MAX_TURNS="${REVIEW_MAX_TURNS:-6}"
BUDGET="${REVIEW_MAX_BUDGET_USD:-3.00}"
MODEL="${REVIEW_MODEL:-}"
BARE=0
FAIL_ON="blocking"
GUIDELINES=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --max-turns) MAX_TURNS="$2"; shift 2 ;;
    --max-budget-usd) BUDGET="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --bare) BARE=1; shift ;;
    --fail-on) FAIL_ON="$2"; shift 2 ;;
    --guidelines) GUIDELINES="$2"; shift 2 ;;
    -h|--help) usage 0 ;;
    *) echo "claude-review.sh: unknown option '$1'" >&2; usage 1 ;;
  esac
done

command -v claude >/dev/null 2>&1 || { echo "claude-review.sh: 'claude' not on PATH (npm install -g @anthropic-ai/claude-code)" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "claude-review.sh: git not found" >&2; exit 1; }

if [[ -z "$BASE" ]]; then
  if git rev-parse --verify -q origin/main >/dev/null; then BASE="origin/main"; else BASE="main"; fi
fi
[[ -z "$GUIDELINES" && -f REVIEW.md ]] && GUIDELINES="REVIEW.md"

mkdir -p "$OUT"
DIFF="$(git diff "${BASE}...HEAD" -- . ':(exclude)*.pbxproj' ':(exclude)*.resolved' ':(exclude)*.lock' || true)"
STAT="$(git diff --stat "${BASE}...HEAD" || true)"
if [[ -z "$DIFF" ]]; then
  echo "claude-review.sh: no diff between $BASE and HEAD; nothing to review"
  printf '{"findings":[],"verdict":"approve","note":"empty diff"}\n' > "$OUT/review.json"
  printf '# Claude review\n\nNo changes between %s and HEAD.\n' "$BASE" > "$OUT/review.md"
  exit 0
fi

SYSTEM="You are a senior iOS/tvOS engineer reviewing a Swift diff. Review ONLY the diff you are given (it is on stdin).
Report defects, not style. Check, in order:
1. Swift 6 concurrency: non-Sendable values crossing isolation, @unchecked Sendable or nonisolated(unsafe) without a proof comment, UI state mutated off the main actor, Task {} capturing self where the task can outlive the owner.
2. Memory: retain cycles (strong self in long-lived closures, strong delegates), Combine subscriptions not stored or cancelled, NotificationCenter/KVO observers never removed.
3. SwiftUI performance and correctness: heavy work in body, misuse of @State/@Observable/@Bindable, view identity churn, AnyView, image decoding on the main thread, NavigationView instead of NavigationStack.
4. tvOS: views unreachable by the focus engine, missing focusSection()/UIFocusGuide, .disabled() breaking navigation, hover/tap-only affordances, parallax/press feedback missing on custom focusable views.
5. Architecture: forbidden imports across layers (Core must not import UI/persistence frameworks; UI and Platform never import each other), business logic in views, hand-edited .pbxproj/lockfiles/entitlements.
6. Accessibility and localization: missing accessibility labels on custom controls, hard-coded user-facing strings, Dynamic Type breakage.
7. Tests: new logic without Swift Testing coverage; XCTest and Swift Testing mixed in one target; weakened assertions.
Severity: blocking = will crash, corrupt data, race, or ship an unreachable tvOS screen; important = real defect but shippable with a follow-up; nit = minor. Cite file and line from the diff hunks. Give a concrete fix for every finding. If nothing is wrong, return an empty findings array and verdict approve."
if [[ -n "$GUIDELINES" && -f "$GUIDELINES" ]]; then
  SYSTEM="$SYSTEM

Repository review guidelines ($GUIDELINES):
$(cat "$GUIDELINES")"
fi

SCHEMA='{"type":"object","properties":{"verdict":{"type":"string","enum":["approve","request-changes"]},"findings":{"type":"array","items":{"type":"object","properties":{"severity":{"type":"string","enum":["blocking","important","nit"]},"category":{"type":"string"},"file":{"type":"string"},"line":{"type":"integer"},"summary":{"type":"string"},"fix":{"type":"string"}},"required":["severity","category","file","summary","fix"]}}},"required":["verdict","findings"]}'

PROTECTED="$(git diff --name-only "${BASE}...HEAD" -- '*.pbxproj' '*.xcworkspacedata' '*.resolved' '*.lock' '*.entitlements' '*.mobileprovision' '*/Info.plist' 'Info.plist' 2>/dev/null || true)"
PROMPT="Review the Swift diff on stdin (base ${BASE}...HEAD). Diff stat:
${STAT}

Protected/generated files changed in this range (their diffs are excluded from stdin for size; treat any unexplained change as Important per REVIEW.md):
${PROTECTED:-none}"

ALLOWED="Read,Grep,Glob,Bash(git diff *),Bash(git log *),Bash(git show *)"

CMD=(claude -p "$PROMPT"
     --output-format json
     --json-schema "$SCHEMA"
     --max-turns "$MAX_TURNS"
     --max-budget-usd "$BUDGET"
     --permission-mode dontAsk
     --allowedTools "$ALLOWED"
     --append-system-prompt "$SYSTEM"
     --no-session-persistence)
[[ -n "$MODEL" ]] && CMD+=(--model "$MODEL")
[[ "$BARE" -eq 1 ]] && CMD+=(--bare)

echo "claude-review.sh: reviewing ${BASE}...HEAD ($(printf '%s\n' "$DIFF" | wc -l | tr -d ' ') diff lines, max-turns=$MAX_TURNS, budget=\$$BUDGET)"
set +e
printf '%s\n' "$DIFF" | "${CMD[@]}" > "$OUT/review.json"
STATUS=$?
set -e
if [[ "$STATUS" -ne 0 ]]; then
  echo "claude-review.sh: claude exited $STATUS; see $OUT/review.json" >&2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "claude-review.sh: jq not installed; raw JSON is in $OUT/review.json" >&2
  exit "$STATUS"
fi

COST="$(jq -r '.total_cost_usd // "?"' "$OUT/review.json")"
SESSION="$(jq -r '.session_id // "?"' "$OUT/review.json")"
VERDICT="$(jq -r '.structured_output.verdict // "unknown"' "$OUT/review.json")"
{
  echo "# Claude review of ${BASE}...HEAD"
  echo
  echo "- Verdict: **${VERDICT}**"
  echo "- Cost: \$${COST} (client-side estimate) | session: ${SESSION}"
  echo
  for sev in blocking important nit; do
    n="$(jq -r --arg s "$sev" '[.structured_output.findings[]? | select(.severity == $s)] | length' "$OUT/review.json")"
    [[ "$n" == "0" ]] && continue
    echo "## ${sev} (${n})"
    jq -r --arg s "$sev" '.structured_output.findings[]? | select(.severity == $s)
      | "- [\(.severity)] `\(.file):\(.line // "?")` (\(.category)) — \(.summary)\n  - Fix: \(.fix)"' "$OUT/review.json"
    echo
  done
  if [[ "$(jq -r '[.structured_output.findings[]?] | length' "$OUT/review.json")" == "0" ]]; then
    echo "No findings."
  fi
} > "$OUT/review.md"
cat "$OUT/review.md"

case "$FAIL_ON" in
  none) exit "$STATUS" ;;
  blocking) n="$(jq -r '[.structured_output.findings[]? | select(.severity == "blocking")] | length' "$OUT/review.json")" ;;
  important) n="$(jq -r '[.structured_output.findings[]? | select(.severity == "blocking" or .severity == "important")] | length' "$OUT/review.json")" ;;
  *) echo "claude-review.sh: --fail-on must be blocking|important|none" >&2; exit 1 ;;
esac
if [[ "$n" != "0" ]]; then
  echo "claude-review.sh: $n finding(s) at or above '$FAIL_ON'" >&2
  exit 1
fi
exit "$STATUS"

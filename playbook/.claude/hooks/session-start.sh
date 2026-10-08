#!/usr/bin/env bash
# .claude/hooks/session-start.sh — SessionStart hook (all sources: startup, resume, clear, compact, fork).
# Plain-text stdout from a SessionStart command hook becomes context for Claude (hooks reference, quoted in
# research/notes/governance_and_context_engineering.md KQ3). Keep it short: this costs tokens every session.
# Prints: git branch/status, the last scripts/xcb.sh result (.claude/last-build.json), simulator availability.
# composed: the content is this playbook's own; the official examples echo reminders or `git log --oneline -5`.
# Never blocks (always exits 0). Needs no stdin beyond `source`; jq optional.
set -euo pipefail

INPUT="$(cat || true)"

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

SOURCE="$(json_get source)"
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$ROOT" 2>/dev/null || exit 0
SIM_IOS_NAME="${SIM_IOS_NAME:-iPhone 16}"
SIM_TVOS_NAME="${SIM_TVOS_NAME:-Apple TV 4K (3rd generation)}"

echo "## Session status (.claude/hooks/session-start.sh, source=${SOURCE:-unknown})"

# --- git ---------------------------------------------------------------------------------------
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch="$(git branch --show-current 2>/dev/null || echo detached)"
  dirty="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  ab=""
  if git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
    ab="$(git rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null | awk '{printf "behind %s / ahead %s", $1, $2}')"
  fi
  echo "- git: branch '$branch' ${ab:+($ab)}; $dirty uncommitted path(s); last commit: $(git log -1 --format='%h %s' 2>/dev/null | cut -c1-80)"
fi

# --- last build (written by scripts/xcb.sh) ------------------------------------------------------
if [[ -f .claude/last-build.json ]]; then
  if command -v jq >/dev/null 2>&1; then
    echo "- last xcb.sh run: $(jq -r '"\(.action) \(.platform) scheme=\(.scheme) status=\(.status) at \(.finished_at); log=\(.log)"' .claude/last-build.json 2>/dev/null || echo 'unreadable')"
  else
    echo "- last xcb.sh run: $(head -c 300 .claude/last-build.json)"
  fi
else
  echo "- last xcb.sh run: none yet (run scripts/xcb.sh build ios)"
fi

# --- toolchain + simulators (macOS only) --------------------------------------------------------
if [[ "$(uname -s)" == "Darwin" ]]; then
  xc="$(xcodebuild -version 2>/dev/null | head -n 1 || echo 'Xcode: not found')"
  echo "- toolchain: $xc; xcbeautify=$(command -v xcbeautify >/dev/null && echo yes || echo no) swiftlint=$(command -v swiftlint >/dev/null && echo yes || echo no) swiftformat=$(command -v swiftformat >/dev/null && echo yes || echo no) jq=$(command -v jq >/dev/null && echo yes || echo no)"
  booted="$(xcrun simctl list devices booted 2>/dev/null | grep -c '(Booted)' || true)"
  avail="$(xcrun simctl list devices available 2>/dev/null || true)"
  ios_ok="no"; tv_ok="no"
  printf '%s' "$avail" | grep -Fq "$SIM_IOS_NAME (" && ios_ok="yes"
  printf '%s' "$avail" | grep -Fq "$SIM_TVOS_NAME (" && tv_ok="yes"
  echo "- simulators: ${booted:-0} booted; '$SIM_IOS_NAME' available=$ios_ok; '$SIM_TVOS_NAME' available=$tv_ok (scripts/sim.sh list)"
else
  echo "- host is $(uname -s): Xcode/simulator checks skipped (this playbook builds on macOS only)"
fi

if [[ "$SOURCE" == "compact" ]]; then
  echo "- after compaction: re-read CLAUDE.md > Session hygiene; keep the list of modified files and the exact xcb.sh/test commands you were using."
fi
exit 0

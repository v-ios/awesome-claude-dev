#!/usr/bin/env bash
# .claude/hooks/stop-gate.sh — Stop hook: Claude may not end its turn with Swift changes that do not build.
#
# Contract (hooks reference, quoted in research/notes/governance_and_context_engineering.md KQ3):
#   * stdin JSON has `stop_hook_active`: true when Claude is already continuing because of a stop hook —
#     exit 0 then, "to avoid blocking on a condition that will never resolve"
#   * exit 2 + stderr = block the stop; stderr is fed back to Claude as the reason
#   * Claude Code applies an 8-consecutive-continuation cap (raise with CLAUDE_CODE_STOP_HOOK_BLOCK_CAP);
#     after that the stop goes through regardless, so this gate cannot loop forever
#
# What it does: if any .swift file changed since the last successful scripts/xcb.sh run, run a quiet
# incremental build (`scripts/xcb.sh build <platform>`) bounded by STOP_GATE_MAX_SECONDS, and block with the last
# 40 log lines if it fails. It deliberately does NOT run the whole test suite on every stop (slow); use
# /test for targeted tests and CI for the full suite. The hook's own `timeout` in settings.json is 900 s.
#
# Env: STOP_GATE_PLATFORM=ios|tvos|both (default ios)  STOP_GATE_MAX_SECONDS (default 600, split across platforms)
#      STOP_GATE_RUN_ARCH_CHECK=1 (also run scripts/arch-check.sh)  STOP_GATE_DISABLED=1 (skip)
# composed: the gate logic is this playbook's own; validate in your repo.
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

[[ "${STOP_GATE_DISABLED:-0}" == "1" ]] && exit 0
if [[ "$(json_get stop_hook_active)" == "true" ]]; then
  exit 0
fi
if [[ "$(uname -s)" != "Darwin" ]]; then
  exit 0   # no Xcode here; nothing to gate
fi

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$ROOT" || exit 0
[[ -x scripts/xcb.sh ]] || exit 0

# Anything Swift changed in the working tree?
changed="$(git status --porcelain --untracked-files=all -- '*.swift' 2>/dev/null | head -n 1 || true)"
[[ -n "$changed" ]] || exit 0

# Skip when the last xcb.sh run succeeded and no .swift file is newer than it.
if [[ -f .claude/last-build.json ]]; then
  last_status="$(jq -r '.status // 1' .claude/last-build.json 2>/dev/null || echo 1)"
  newer="$(find . -name '*.swift' -newer .claude/last-build.json \
             -not -path './.derivedData/*' -not -path './.build/*' -not -path './build/*' \
             -not -path './Pods/*' -not -path './.claude/worktrees/*' 2>/dev/null | head -n 1 || true)"
  if [[ "$last_status" == "0" && -z "$newer" ]]; then
    exit 0
  fi
fi

MAX="${STOP_GATE_MAX_SECONDS:-600}"
run_with_timeout() { # run_with_timeout <seconds> <cmd...>; returns 124 on timeout (bash 3.2 has no `timeout`)
  local secs="$1"; shift
  "$@" & local pid=$!
  ( sleep "$secs"; kill -TERM "$pid" 2>/dev/null ) & local killer=$!
  local st=0
  wait "$pid" || st=$?
  kill "$killer" 2>/dev/null || true
  wait "$killer" 2>/dev/null || true
  if [[ "$st" -eq 143 ]]; then return 124; fi
  return "$st"
}

platforms="${STOP_GATE_PLATFORM:-ios}"
[[ "$platforms" == "both" ]] && platforms="ios tvos"
# The hook's own timeout in settings.json is 900 s; keep the sum of per-platform budgets under it.
count=0; for p in $platforms; do count=$((count + 1)); done
MAX=$((MAX / count))
for p in $platforms; do
  log="$(mktemp -t stop-gate.XXXXXX)"
  st=0
  run_with_timeout "$MAX" scripts/xcb.sh build "$p" > "$log" 2>&1 || st=$?
  if [[ "$st" -eq 124 ]]; then
    echo "stop-gate: scripts/xcb.sh build $p exceeded ${MAX}s and was stopped. Run it yourself and fix the build before finishing (or ask the user to raise STOP_GATE_MAX_SECONDS)." >&2
    rm -f "$log"; exit 2
  elif [[ "$st" -ne 0 ]]; then
    echo "stop-gate: the $p build fails with your Swift changes. Fix the root cause before finishing (do not suppress errors). Last 40 lines:" >&2
    tail -n 40 "$log" >&2
    rm -f "$log"; exit 2
  fi
  rm -f "$log"
done

if [[ "${STOP_GATE_RUN_ARCH_CHECK:-0}" == "1" && -x scripts/arch-check.sh ]]; then
  if ! out="$(scripts/arch-check.sh --quiet 2>&1)"; then
    echo "stop-gate: architecture boundary violations:" >&2
    printf '%s\n' "$out" | tail -n 20 >&2
    exit 2
  fi
fi
exit 0

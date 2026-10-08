#!/usr/bin/env bash
# scripts/eval-context-tool.sh — A/B harness: does a context tool (GitNexus, swift-lsp, ...) help Claude Code
# on YOUR iOS/tvOS repo? Runs each task N times, in fresh git worktrees, under a baseline arm (no MCP) and a
# tool arm (MCP enabled), captures cost/turn/duration/usage from `claude -p --output-format json`, runs a
# hidden oracle for pass/fail, and writes a CSV.
#
# Design from research/notes/gitnexus_evaluation.md KQ7: fresh worktree per run, hidden oracle required for
# "resolved", a baseline_nomcp arm, interleaved arms, pinned versions, and "token savings on a failed task are
# flagged, not celebrated". Headless flags from the Claude Code docs quoted there: --strict-mcp-config,
# --mcp-config, --output-format json, --max-turns, --max-budget-usd, --permission-mode, --allowedTools,
# --disallowedTools, --no-session-persistence, --bare, --append-system-prompt.
# composed: everything else is this harness's own orchestration. The GitNexus commands in preflight_gitnexus()
# are copied from the notes but were NOT executed while writing this; TODO markers show where a
# tool-specific query must be filled in. The JSON result fields other than total_cost_usd/session_id/result
# (num_turns, duration_ms, duration_api_ms, usage.*) are taken from the task brief — confirm with
#   claude -p "hi" --output-format json | jq 'keys'   on your Claude Code version.
#
# Usage:
#   scripts/eval-context-tool.sh --tasks tasks.tsv --tool-mcp tool.mcp.json [options]
#   scripts/eval-context-tool.sh --preflight-only --tool gitnexus
#
# tasks.tsv: one task per line:  <task-id> TAB <prompt> [TAB <oracle shell command, run inside the worktree; exit 0 = pass>]
#            '#' lines are ignored. Keep hidden tests OUTSIDE the repo; the oracle may copy them in after the run.
#
# Options:
#   --tool-mcp FILE        .mcp.json-style config for the tool arm (--mcp-config + --strict-mcp-config)
#   --tool NAME            gitnexus | swift-lsp | other   (selects preflight checks; default other)
#   --arms LIST            default: baseline,tool
#   --runs N               repetitions per task x arm (default 5; GitLab's GKG study used 11 — no API seed)
#   --base-ref REF         commit the worktrees are created from (default HEAD; commit your .claude/ first)
#   --out FILE             CSV path (default build/eval/results-<stamp>.csv)
#   --max-turns N          default 40            --max-budget-usd X   default 5.00
#   --model M              identical across arms  --permission-mode M  default acceptEdits
#   --allowed-tools LIST   default: Read,Edit,Write,Grep,Glob,Bash(xcodebuild *),Bash(swift *),Bash(git diff *),Bash(git status *),Bash(scripts/*)
#   --prepare CMD          run inside each TOOL-arm worktree before the task (e.g. "gitnexus analyze --skip-skills --skip-agents-md")
#   --no-skills            add --disallowedTools Skill to every arm (isolates the tool effect from skill effects)
#   --bare                 claude --bare + CLAUDE.md injected via --append-system-prompt (identical context; needs ANTHROPIC_API_KEY)
#   --keep-worktrees       do not remove worktrees afterwards
#   --preflight-only       run the "did the tool actually parse Swift?" gate and exit
#
# Portable harness (bash/git/jq); the tasks themselves may need macOS+Xcode, which is the oracle's business.
set -euo pipefail

usage() {
  sed -n '2,46p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-1}"
}

TASKS=""; TOOL_MCP=""; TOOL="other"; ARMS="baseline,tool"; RUNS=5; BASE_REF="HEAD"; OUT=""
MAX_TURNS=40; BUDGET="5.00"; MODEL=""; PERM="acceptEdits"
ALLOWED="Read,Edit,Write,Grep,Glob,Bash(xcodebuild *),Bash(swift *),Bash(git diff *),Bash(git status *),Bash(scripts/*)"
PREPARE=""; NO_SKILLS=0; BARE=0; KEEP=0; PREFLIGHT_ONLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tasks) TASKS="$2"; shift 2 ;;
    --tool-mcp) TOOL_MCP="$2"; shift 2 ;;
    --tool) TOOL="$2"; shift 2 ;;
    --arms) ARMS="$2"; shift 2 ;;
    --runs) RUNS="$2"; shift 2 ;;
    --base-ref) BASE_REF="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --max-turns) MAX_TURNS="$2"; shift 2 ;;
    --max-budget-usd) BUDGET="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --permission-mode) PERM="$2"; shift 2 ;;
    --allowed-tools) ALLOWED="$2"; shift 2 ;;
    --prepare) PREPARE="$2"; shift 2 ;;
    --no-skills) NO_SKILLS=1; shift ;;
    --bare) BARE=1; shift ;;
    --keep-worktrees) KEEP=1; shift ;;
    --preflight-only) PREFLIGHT_ONLY=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "eval-context-tool.sh: unknown option '$1'" >&2; usage 1 ;;
  esac
done

need() { command -v "$1" >/dev/null 2>&1 || { echo "eval-context-tool.sh: '$1' is required" >&2; exit 1; }; }
need git; need jq; need claude

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
STAMP="$(date +%Y%m%d-%H%M%S)"
WORK="$REPO_ROOT/build/eval/$STAMP"
mkdir -p "$WORK"
[[ -n "$OUT" ]] || OUT="$REPO_ROOT/build/eval/results-$STAMP.csv"

# ---- pre-flight: prove the tool parsed Swift before spending money -------------------------
preflight_common() {
  echo "== preflight: versions (record these in your write-up)"
  echo "   claude: $(claude --version 2>/dev/null | head -n 1)"
  echo "   git ref: $(git rev-parse "$BASE_REF")  host: $(uname -sm)"
  echo "   swift/objc files tracked: $(git ls-files | grep -E '\.(swift|m|mm|h)$' | wc -l | tr -d ' ')"
}

preflight_gitnexus() {
  # Source: gitnexus_evaluation.md KQ2/KQ7 — the Swift grammar is OPTIONAL and can silently be absent.
  local gn="${GITNEXUS_BIN:-gitnexus}" err="$WORK/gitnexus-analyze.stderr" wt="$WORK/preflight-wt" fail=0
  command -v "$gn" >/dev/null 2>&1 || { echo "preflight: '$gn' not found; pin a version: npm i -g gitnexus@1.6.12" >&2; return 1; }
  echo "== preflight(gitnexus): $("$gn" --version 2>/dev/null || echo 'version unknown')"
  git worktree add --detach "$wt" "$BASE_REF" >/dev/null
  (cd "$wt" && "$gn" analyze 2> "$err") || { echo "preflight: gitnexus analyze failed; see $err" >&2; fail=1; }
  if grep -Fq 'optional grammar "tree-sitter-swift" is unavailable' "$err" || grep -Fq 'GITNEXUS_SKIP_OPTIONAL_GRAMMARS' "$err"; then
    echo "preflight: FAIL — Swift grammar missing (.swift files not parsed). stderr:" >&2
    grep -F 'tree-sitter-swift' "$err" >&2 || true
    fail=1
  else
    echo "   no Swift-grammar warning on stderr: OK"
  fi
  local tracked indexed
  tracked="$(cd "$wt" && git ls-files | grep -E '\.(swift|m|mm|h)$' | wc -l | tr -d ' ')"
  # TODO: confirm the field name in `gitnexus status --json` (the notes record stats as files/symbols/processes).
  indexed="$(cd "$wt" && "$gn" status --json 2>/dev/null | jq -r '.files // .stats.files // empty' || true)"
  echo "   tracked source files: $tracked   indexed files (status --json): ${indexed:-unknown}"
  if [[ -n "$indexed" && "$indexed" -lt $((tracked * 8 / 10)) ]]; then
    echo "preflight: FAIL — indexed file count is below 80% of tracked Swift/ObjC files (check GITNEXUS_MAX_FILE_SIZE skips)" >&2
    fail=1
  fi
  # Symbol spot-checks: known symbols must resolve to class/method nodes, not just file nodes.
  # TODO: set EVAL_SPOTCHECK_SYMBOLS="AppMain HomeViewController HomeView SomeProtocol" (10 Swift + 5 ObjC recommended)
  local sym
  for sym in ${EVAL_SPOTCHECK_SYMBOLS:-}; do
    if (cd "$wt" && "$gn" context "$sym" 2>/dev/null | grep -Eqi 'class|struct|method|function|protocol'); then
      echo "   context $sym: OK"
    else
      echo "preflight: WARN — gitnexus context $sym returned no class/method node" >&2; fail=1
    fi
  done
  # TODO: verify the node property name against the gitnexus://repo/<name>/schema resource before trusting this count.
  local count
  count="$(cd "$wt" && "$gn" cypher "MATCH (n) WHERE n.filePath ENDS WITH '.swift' RETURN count(n)" 2>/dev/null | grep -Eo '[0-9]+' | tail -n 1 || true)"
  echo "   cypher count of .swift nodes: ${count:-unknown}"
  if [[ -n "$count" && "$count" -eq 0 ]]; then echo "preflight: FAIL — zero Swift nodes in the graph" >&2; fail=1; fi
  # TODO (Xcode projects without Package.swift): confirm App and extension targets resolve to separate modules
  #      (a method defined in both targets must not cross-link), and that a symbol inside #if os(tvOS) is found.
  git worktree remove --force "$wt" >/dev/null 2>&1 || true
  return "$fail"
}

preflight_swift_lsp() {
  echo "== preflight(swift-lsp)"
  command -v sourcekit-lsp >/dev/null 2>&1 && echo "   sourcekit-lsp on PATH: OK" || echo "preflight: WARN — sourcekit-lsp not on PATH (xcrun --find sourcekit-lsp)" >&2
  if ls ./*.xcodeproj >/dev/null 2>&1 && [[ ! -f buildServer.json ]]; then
    echo "preflight: WARN — .xcodeproj without buildServer.json; run xcode-build-server config -project X.xcodeproj -scheme Y after an Xcode build" >&2
  fi
  # TODO: run one short `claude -p` edit in the tool arm and grep its stream-json for "Found N new diagnostic issues"
  #       (the documented sign that the language server started); fail the gate if it never appears.
}

preflight_other() {
  echo "== preflight(other): TODO — add a check that proves YOUR tool indexed .swift files (symbol lookup of a known type, index stats, or a stderr warning scan)."
}

preflight_common
case "$TOOL" in
  gitnexus) preflight_gitnexus || { echo "eval-context-tool.sh: preflight failed; fix before running the A/B" >&2; exit 1; } ;;
  swift-lsp) preflight_swift_lsp ;;
  *) preflight_other ;;
esac
[[ "$PREFLIGHT_ONLY" -eq 1 ]] && exit 0

# ---- A/B runs -------------------------------------------------------------------------------
[[ -n "$TASKS" && -f "$TASKS" ]] || { echo "eval-context-tool.sh: --tasks FILE is required" >&2; usage 1; }
EMPTY_MCP="$WORK/empty.mcp.json"
printf '{"mcpServers":{}}\n' > "$EMPTY_MCP"
if [[ "$ARMS" == *tool* ]]; then
  [[ -n "$TOOL_MCP" && -f "$TOOL_MCP" ]] || { echo "eval-context-tool.sh: --tool-mcp FILE is required for the tool arm" >&2; exit 1; }
  TOOL_MCP="$(cd "$(dirname "$TOOL_MCP")" && pwd)/$(basename "$TOOL_MCP")"
fi
SYSTEM_EXTRA=""
if [[ "$BARE" -eq 1 && -f CLAUDE.md ]]; then SYSTEM_EXTRA="$(cat CLAUDE.md)"; fi

echo "task_id,arm,run,pass,oracle_exit,is_error,total_cost_usd,num_turns,duration_ms,duration_api_ms,input_tokens,output_tokens,cache_read_tokens,cache_creation_tokens,session_id,files_changed,insertions,deletions,wall_seconds,worktree" > "$OUT"

csv_escape() { local s="${1//\"/\"\"}"; printf '"%s"' "$s"; }

run_one() { # run_one <task_id> <prompt> <oracle> <arm> <run>
  local id="$1" prompt="$2" oracle="$3" arm="$4" run="$5"
  local wt="$WORK/wt-${id}-${arm}-${run}" json="$WORK/${id}-${arm}-${run}.json"
  git worktree add --detach "$wt" "$BASE_REF" >/dev/null 2>&1 < /dev/null
  local cmd=(claude -p "$prompt" --output-format json --max-turns "$MAX_TURNS" --max-budget-usd "$BUDGET"
             --permission-mode "$PERM" --allowedTools "$ALLOWED" --no-session-persistence --strict-mcp-config)
  case "$arm" in
    baseline) cmd+=(--mcp-config "$EMPTY_MCP") ;;
    tool)
      cmd+=(--mcp-config "$TOOL_MCP")
      if [[ -n "$PREPARE" ]]; then (cd "$wt" && bash -c "$PREPARE") < /dev/null > "$WORK/${id}-${arm}-${run}.prepare.log" 2>&1 || echo "   prepare failed for $id/$arm/$run (see .prepare.log)" >&2; fi ;;
    *) echo "eval-context-tool.sh: unknown arm '$arm'" >&2; return 1 ;;
  esac
  [[ -n "$MODEL" ]] && cmd+=(--model "$MODEL")
  [[ "$NO_SKILLS" -eq 1 ]] && cmd+=(--disallowedTools Skill)
  if [[ "$BARE" -eq 1 ]]; then cmd+=(--bare); [[ -n "$SYSTEM_EXTRA" ]] && cmd+=(--append-system-prompt "$SYSTEM_EXTRA"); fi

  local t0 t1 st=0
  t0="$(date +%s)"
  # < /dev/null: claude -p reads piped stdin, and this runs inside `while read` loops (tasks, arms)
  (cd "$wt" && "${cmd[@]}") < /dev/null > "$json" 2> "${json%.json}.stderr" || st=$?
  t1="$(date +%s)"

  local pass="" oexit=""
  if [[ -n "$oracle" ]]; then
    if (cd "$wt" && bash -c "$oracle") < /dev/null > "${json%.json}.oracle.log" 2>&1; then pass=1; oexit=0; else oexit=$?; pass=0; fi
  fi
  local shortstat files ins dels
  shortstat="$(cd "$wt" && git add -A >/dev/null 2>&1 && git diff --cached --shortstat 2>/dev/null || true)"
  files="$(printf '%s' "$shortstat" | grep -Eo '[0-9]+ file' | grep -Eo '[0-9]+' || echo 0)"
  ins="$(printf '%s' "$shortstat" | grep -Eo '[0-9]+ insertion' | grep -Eo '[0-9]+' || echo 0)"
  dels="$(printf '%s' "$shortstat" | grep -Eo '[0-9]+ deletion' | grep -Eo '[0-9]+' || echo 0)"

  local q='[(.is_error // false), (.total_cost_usd // ""), (.num_turns // ""), (.duration_ms // ""), (.duration_api_ms // ""),
            (.usage.input_tokens // ""), (.usage.output_tokens // ""), (.usage.cache_read_input_tokens // ""),
            (.usage.cache_creation_input_tokens // ""), (.session_id // "")] | @csv'
  local fields
  fields="$(jq -r "$q" "$json" 2>/dev/null || printf '"parse-error","","","","","","","","",""')"
  printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' "$(csv_escape "$id")" "$arm" "$run" "$pass" "$oexit" "$fields" \
    "$files" "$ins" "$dels" "$((t1 - t0))" "$(csv_escape "$wt")" >> "$OUT"
  echo "   $id [$arm] run $run: pass=${pass:-n/a} claude_exit=$st wall=$((t1 - t0))s cost=$(jq -r '.total_cost_usd // "?"' "$json" 2>/dev/null)"
  [[ "$KEEP" -eq 1 ]] || git worktree remove --force "$wt" >/dev/null 2>&1 < /dev/null || true
}

shuffle_arms() { # prints the arms in random order, one per line (interleave to spread API variance)
  local arr=() a
  IFS=',' read -r -a arr <<<"$1"
  for a in "${arr[@]}"; do printf '%s %s\n' "$RANDOM" "$a"; done | sort -n | cut -d' ' -f2
}

echo "== running: runs=$RUNS arms=$ARMS tasks=$TASKS -> $OUT"
for run in $(seq 1 "$RUNS"); do
  while IFS=$'\t' read -r id prompt oracle || [[ -n "$id" ]]; do
    [[ -z "$id" || "$id" == \#* ]] && continue
    while IFS= read -r arm; do
      run_one "$id" "$prompt" "${oracle:-}" "$arm" "$run"
    done < <(shuffle_arms "$ARMS")
  done < "$TASKS"
done
echo "== done: $OUT"
echo "   Report medians/IQR per task per arm; flag any arm that saves tokens on tasks it FAILS."

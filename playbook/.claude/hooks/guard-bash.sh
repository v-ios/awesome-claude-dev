#!/usr/bin/env bash
# .claude/hooks/guard-bash.sh — PreToolUse hook for Bash. Inspects the full command text and
#   * blocks (exit 2, reason on stderr): `git push --force|-f|--force-with-lease`, `+ref:` force refspecs,
#     `rm -r*` of anything outside DerivedData/.build/build, `pod deintegrate`
#   * asks (PreToolUse JSON permissionDecision "ask"): `xcodebuild clean` of the whole workspace/project
#   * allows (permissionDecision "allow"): a command that is ONLY `rm -rf` of allow-listed build directories,
#     so the `Bash(rm -rf *)` ask-rule in settings.json does not prompt for the routine case
#
# Hook I/O contract from research/notes/governance_and_context_engineering.md KQ3 (hooks reference):
# stdin JSON with tool_input.command; exit 2 blocks; stdout JSON {"hookSpecificOutput":{"hookEventName":
# "PreToolUse","permissionDecision":"allow|deny|ask","permissionDecisionReason":"..."}} on exit 0.
#
# LIMITS (read this before trusting it): permission deny rules and this hook match the command TEXT Claude
# writes. `/bin/rm -rf x`, `bash -c 'rm -rf x'`, `git -C . push --force`, `env rm ...` or a script that does
# the rm internally are NOT caught here — the docs say so (permissions page: "Bash(rm *) stops rm -rf build/
# but not /bin/rm -rf build/ or bash -c 'rm -rf build/'"). The OS sandbox (settings.json "sandbox", /sandbox)
# is the real guard for filesystem and network; this hook catches what Claude normally writes. The team
# rule in CLAUDE.md ("re-spelling a denied command is forbidden; stop and ask") covers the rest.
#
# composed: the command parsing and allow-list are this playbook's own; validate in your repo.
# Overrides: GUARD_ALLOW_XCODEBUILD_CLEAN=1 (skip the clean prompt), GUARD_BASH_DISABLED=1 (skip the hook).
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

[[ "${GUARD_BASH_DISABLED:-0}" == "1" ]] && exit 0

CMD="$(json_get tool_input.command)"
[[ -n "$CMD" ]] || exit 0

block() { echo "Blocked by .claude/hooks/guard-bash.sh: $1" >&2; exit 2; }
ask()   { printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$1"; exit 0; }
allow() { printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"%s"}}\n' "$1"; exit 0; }

# allow-listed rm targets: build products only
rm_target_allowed() {
  local t="$1"
  t="${t//\"/}"; t="${t//\'/}"
  # never auto-allow traversal, globs, or shell expansion inside the target
  [[ "$t" == *..* || "$t" == *'*'* || "$t" == *'?'* || "$t" == *'`'* || "$t" == *'$('* ]] && return 1
  [[ "$t" =~ ^(\./)?(\.derivedData|DerivedData|\.build|build|\.spm|\.swiftpm)(/.*)?$ ]] && return 0
  [[ "$t" =~ ^\$\{?DERIVED_DATA\}?(/.*)?$ ]] && return 0
  [[ "$t" == *"/Library/Developer/Xcode/DerivedData" || "$t" == *"/Library/Developer/Xcode/DerivedData/"* ]] && return 0
  return 1
}

ASK_REASON=""
ONLY_ALLOWED_RM=1
SEGMENTS=0

# Split on the separators the permission system recognizes (&&, ||, ;, |, &, newline); conservative on `&` in strings.
while IFS= read -r seg; do
  [[ -z "${seg//[[:space:]]/}" ]] && continue
  SEGMENTS=$((SEGMENTS + 1))

  # 1. force push ------------------------------------------------------------------------------
  if [[ "$seg" =~ (^|[[:space:]])git([[:space:]]+-[^[:space:]]+)*[[:space:]]+push([[:space:]]|$) ]]; then
    # -f, combined short flags containing f (-uf), --force, --force-with-lease[=ref], --force-if-includes, +ref[:ref]
    if [[ "$seg" =~ [[:space:]]-[A-Za-z]*f[A-Za-z]*([[:space:]]|$) ]] || [[ "$seg" =~ [[:space:]]--force[A-Za-z=/-]*([[:space:]]|$) ]] || [[ "$seg" =~ [[:space:]]\+[^[:space:]]+ ]]; then
      block "force push is not allowed ($seg). Ask the user; if the branch is yours and this is deliberate, they can run it."
    fi
    ONLY_ALLOWED_RM=0
  fi

  # 2. pod deintegrate --------------------------------------------------------------------------
  if [[ "$seg" =~ (^|[[:space:]])pod[[:space:]]+deintegrate([[:space:]]|$) ]]; then
    block "pod deintegrate rewrites the Xcode project; needs human sign-off."
  fi

  # 3. xcodebuild clean -------------------------------------------------------------------------
  if [[ "$seg" =~ (^|[[:space:]])xcodebuild([[:space:]]|$) ]] && [[ "$seg" =~ [[:space:]]clean([[:space:]]|$) ]]; then
    if [[ "${GUARD_ALLOW_XCODEBUILD_CLEAN:-0}" != "1" ]]; then
      ASK_REASON="xcodebuild clean discards the incremental build cache (slow rebuild). Confirm, or delete only ./.derivedData."
    fi
    ONLY_ALLOWED_RM=0
  fi

  # 4. rm -r / rm -rf outside build directories ---------------------------------------------------
  toks=()
  read -r -a toks <<<"$seg"
  seen_rm=0; recursive=0; paths=()
  for tok in ${toks[@]+"${toks[@]}"}; do
    if [[ "$seen_rm" -eq 0 ]]; then
      case "$tok" in rm|/bin/rm|/usr/bin/rm) seen_rm=1 ;; esac
      continue
    fi
    case "$tok" in
      --recursive) recursive=1 ;;
      --*) ;;
      -*) [[ "$tok" == *r* || "$tok" == *R* ]] && recursive=1 ;;
      *) paths+=("$tok") ;;
    esac
  done
  if [[ "$seen_rm" -eq 1 ]]; then
    if [[ "$recursive" -eq 1 ]]; then
      [[ ${#paths[@]} -gt 0 ]] || block "recursive rm with no path?"
      for p in "${paths[@]}"; do
        rm_target_allowed "$p" || block "recursive delete of '$p' is outside the allow-listed build directories (.derivedData, DerivedData, .build, build, .spm). Delete it by hand if it is really wanted."
      done
    else
      ONLY_ALLOWED_RM=0   # plain rm of files: fall through to normal permission rules
    fi
  else
    ONLY_ALLOWED_RM=0
  fi
done < <(printf '%s\n' "$CMD" | tr '|&;' '\n\n\n')

if [[ -n "$ASK_REASON" ]]; then
  ask "$ASK_REASON"
fi
if [[ "$SEGMENTS" -gt 0 && "$ONLY_ALLOWED_RM" -eq 1 ]]; then
  allow "rm of build directories only (guard-bash.sh allow-list)"
fi
exit 0

#!/usr/bin/env bash
# scripts/arch-check.sh — import-boundary checker: grep over source layers with an allowlist map.
# Used by CI (ci/ios-guardrails.yml), by the architecture-guardian subagent, and by hand.
#
# composed: the import regex follows the `no_ui_import_in_core` custom rule and ArchitectureBoundaryTests from
# tomada1114/ios-template (research/notes/governance_and_context_engineering.md KQ8); the rules-file format
# and allowlist logic are this script's own. It is the THIRD enforcement of the boundaries described in
# .claude/rules/architecture.md (SwiftLint custom rule + Swift Testing suite are the other two).
#
# Usage:
#   scripts/arch-check.sh [--rules FILE] [--list] [--quiet] [DIR...]
#     --rules FILE   rules file (default: $ARCH_RULES_FILE or scripts/arch-rules.conf if present, else built-in)
#     --list         print the effective rules and exit
#     DIR...         restrict the scan to these directories (default: every layer in the rules)
#
# Rules file format (one layer per line; '#' comments; whitespace-insensitive around '|'):
#   <layer-dir> | <module-name> | <allowed project modules, comma-separated> | <extra forbidden frameworks, comma-separated>
# PROJECT_MODULES is the union of all <module-name> fields. Keep the framework lists identical to
# .swiftlint.yml (no_ui_import_in_core) and Tests/ArchitectureBoundaryTests.swift (forbiddenInCore). For each layer, every project module that is
# neither the layer itself nor in its allowlist is forbidden, plus the extra frameworks named on the line.
#
# Exit status: 0 no violations; 1 violations found (printed as path:line: layer 'X' must not import 'Y'); 2 usage.
# Portable: runs on macOS and Linux (no Xcode needed), so the CI lint job can run on ubuntu.
set -euo pipefail

usage() {
  sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-2}"
}

# macOS-only guard is intentionally NOT applied: this script needs only bash, find and grep.

builtin_rules() {
  cat <<'RULES'
# layer-dir           | module          | allowed project modules            | extra forbidden frameworks
Sources/MyAppCore     | MyAppCore       |                                    | SwiftUI,UIKit,AppKit,Cocoa,TVUIKit,TVServices,SwiftData,CoreData,CloudKit,UserNotifications,CoreLocation,Photos,PhotosUI,StoreKit,WidgetKit
Sources/MyAppUI       | MyAppUI         | MyAppCore                          | SwiftData,CoreData
Sources/MyAppPlatform | MyAppPlatform   | MyAppCore                          | SwiftUI
Sources/MyAppFeatures | MyAppFeatures   | MyAppCore,MyAppUI                  | SwiftData,CoreData
App                   | MyApp           | MyAppCore,MyAppUI,MyAppPlatform,MyAppFeatures |
RULES
}

RULES_FILE="${ARCH_RULES_FILE:-}"
LIST=0
QUIET=0
SCAN_DIRS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --rules) RULES_FILE="$2"; shift 2 ;;
    --list) LIST=1; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) usage 0 ;;
    --*) echo "arch-check.sh: unknown option '$1'" >&2; usage 2 ;;
    *) SCAN_DIRS+=("$1"); shift ;;
  esac
done

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$RULES_FILE" && -f "$HERE/arch-rules.conf" ]]; then RULES_FILE="$HERE/arch-rules.conf"; fi

load_rules() {
  if [[ -n "$RULES_FILE" ]]; then
    [[ -f "$RULES_FILE" ]] || { echo "arch-check.sh: rules file not found: $RULES_FILE" >&2; exit 2; }
    cat "$RULES_FILE"
  else
    builtin_rules
  fi
}

# parse into parallel arrays
LAYER_DIR=(); LAYER_MOD=(); LAYER_ALLOW=(); LAYER_EXTRA=()
while IFS= read -r line; do
  line="${line%%#*}"
  [[ -z "${line//[[:space:]]/}" ]] && continue
  IFS='|' read -r d m a x <<<"$line"
  trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }
  LAYER_DIR+=("$(trim "$d")"); LAYER_MOD+=("$(trim "$m")"); LAYER_ALLOW+=("$(trim "${a:-}")"); LAYER_EXTRA+=("$(trim "${x:-}")")
done < <(load_rules)

[[ ${#LAYER_DIR[@]} -gt 0 ]] || { echo "arch-check.sh: no rules loaded" >&2; exit 2; }

PROJECT_MODULES=("${LAYER_MOD[@]}")

in_list() { # in_list <needle> <comma-separated list>
  local n="$1" l=",$2,"
  l="${l//[[:space:]]/}"
  [[ "$l" == *",$n,"* ]]
}

forbidden_for() { # forbidden_for <index> -> prints forbidden module names, one per line
  local i="$1" m
  for m in "${PROJECT_MODULES[@]}"; do
    [[ "$m" == "${LAYER_MOD[$i]}" ]] && continue
    in_list "$m" "${LAYER_ALLOW[$i]}" && continue
    printf '%s\n' "$m"
  done
  if [[ -n "${LAYER_EXTRA[$i]}" ]]; then
    tr ',' '\n' <<<"${LAYER_EXTRA[$i]}" | tr -d '[:space:]' | sed '/^$/d'
  fi
}

if [[ "$LIST" -eq 1 ]]; then
  for i in "${!LAYER_DIR[@]}"; do
    printf '%s (%s) must not import: %s\n' "${LAYER_DIR[$i]}" "${LAYER_MOD[$i]}" "$(forbidden_for "$i" | tr '\n' ' ')"
  done
  exit 0
fi

# Same shape as ios-template's regex: optional attributes (@preconcurrency, @_exported, @testable),
# `import`, optional kind (struct/class/...), then the module; the trailing class rejects longer identifiers
# but accepts `.` so `import struct SwiftUI.Color` is still caught. Uses POSIX classes (no \s, \b) so BSD grep
# on macOS and GNU grep on Linux behave the same.
import_regex() {
  printf '^[[:space:]]*(@[A-Za-z0-9_()]+[[:space:]]+)*import[[:space:]]+((typealias|struct|class|enum|protocol|let|var|func)[[:space:]]+)?(%s)([^A-Za-z0-9_]|$)' "$1"
}

should_scan() { # should_scan <layer-dir>
  [[ ${#SCAN_DIRS[@]} -eq 0 ]] && return 0
  local s
  for s in "${SCAN_DIRS[@]}"; do
    [[ "${1%/}" == "${s%/}" || "${1%/}" == "${s%/}"/* || "${s%/}" == "${1%/}"/* ]] && return 0
  done
  return 1
}

VIOLATIONS=0
SCANNED=0
for i in "${!LAYER_DIR[@]}"; do
  dir="${LAYER_DIR[$i]}"
  should_scan "$dir" || continue
  if [[ ! -d "$dir" ]]; then
    [[ "$QUIET" -eq 1 ]] || echo "arch-check.sh: note: layer directory '$dir' does not exist; skipping" >&2
    continue
  fi
  SCANNED=$((SCANNED + 1))
  while IFS= read -r mod; do
    [[ -n "$mod" ]] || continue
    rx="$(import_regex "$mod")"
    while IFS= read -r hit; do
      [[ -n "$hit" ]] || continue
      file="${hit%%:*}"; rest="${hit#*:}"; lineno="${rest%%:*}"
      printf '%s:%s: error: layer %q (%s) must not import %q\n' "$file" "$lineno" "${LAYER_MOD[$i]}" "$dir" "$mod"
      VIOLATIONS=$((VIOLATIONS + 1))
    done < <(find "$dir" -type f -name '*.swift' -not -path '*/.build/*' -not -path '*/DerivedData/*' \
             -exec grep -nE "$rx" /dev/null {} + 2>/dev/null || true)
  done < <(forbidden_for "$i")
done

if [[ "$SCANNED" -eq 0 ]]; then
  echo "arch-check.sh: no layer directory exists yet; edit the rules (--list) to match your tree" >&2
  exit 2
fi
if [[ "$VIOLATIONS" -gt 0 ]]; then
  echo "arch-check.sh: $VIOLATIONS boundary violation(s). See .claude/rules/architecture.md; do not add swiftlint:disable." >&2
  exit 1
fi
[[ "$QUIET" -eq 1 ]] || echo "arch-check.sh: OK ($SCANNED layer(s) scanned, no forbidden imports)"
exit 0

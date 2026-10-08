#!/usr/bin/env bash
# scripts/symbolicate.sh — symbolicate a .ips/.crash report with current Apple tooling, atos as fallback.
#
# Sources (research/notes/apple_platform_tooling.md §6, Apple "Adding identifiable symbol names to a crash
# report"): `xcrun crashlog <file>`, `CrashSymbolicator.py <crash> -d <dSYM> [-o out.ips]`, and
# `atos -arch arm64 -o <dSYM>/Contents/Resources/DWARF/<binary> -l <load-address> -i <addresses>`.
# composed: the orchestration and dSYM lookup are this script's own; validate in your repo.
#
# Usage:
#   scripts/symbolicate.sh <report.ips|report.crash> [--dsym App.app.dSYM] [--out symbolicated.ips]
#   scripts/symbolicate.sh --atos --dsym App.app.dSYM --load 0x10459c000 [--arch arm64] <addr> [<addr>...]
#   scripts/symbolicate.sh --uuid --dsym App.app.dSYM          # dwarfdump --uuid, to match the report's binary UUID
#
# Behaviour:
#   * report mode without --dsym:   xcrun crashlog <report>   (needs the dSYM findable by Spotlight/Xcode)
#   * report mode with --dsym:      python3 CrashSymbolicator.py <report> -d <dSYM> [-o <out>]
#                                   (from Xcode's CoreSymbolicationDT.framework/Resources; JSON .ips + inlined frames)
#   * --atos:                       single-frame fallback for addresses Xcode leaves unsymbolicated
#   * reports whose extension is not .ips/.crash are copied to a temp file with a .ips extension first
set -euo pipefail

usage() {
  sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-1}"
}

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "symbolicate.sh: Apple's symbolication tools require macOS with Xcode; this host is $(uname -s)." >&2
    exit 1
  fi
}

[[ $# -ge 1 ]] || usage 1
case "$1" in -h|--help|help) usage 0 ;; esac
require_macos

MODE="report"
REPORT=""
DSYM=""
OUT=""
LOAD=""
ARCH="arm64"
ADDRS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --atos) MODE="atos"; shift ;;
    --uuid) MODE="uuid"; shift ;;
    --dsym) DSYM="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --load) LOAD="$2"; shift 2 ;;
    --arch) ARCH="$2"; shift 2 ;;
    -h|--help) usage 0 ;;
    --*) echo "symbolicate.sh: unknown option '$1'" >&2; usage 1 ;;
    *) if [[ "$MODE" == "atos" ]]; then ADDRS+=("$1"); elif [[ -z "$REPORT" ]]; then REPORT="$1"; else ADDRS+=("$1"); fi; shift ;;
  esac
done

dwarf_binary() { # prints the DWARF file inside a dSYM ("provide the path to this file, not just to the .dSYM bundle")
  local d="$1" f
  f="$(find "$d/Contents/Resources/DWARF" -type f -maxdepth 1 2>/dev/null | head -n 1 || true)"
  [[ -n "$f" ]] || { echo "symbolicate.sh: no DWARF file under $d/Contents/Resources/DWARF" >&2; exit 1; }
  echo "$f"
}

case "$MODE" in
  uuid)
    [[ -n "$DSYM" ]] || { echo "symbolicate.sh: --uuid needs --dsym" >&2; exit 1; }
    dwarfdump --uuid "$(dwarf_binary "$DSYM")" ;;
  atos)
    [[ -n "$DSYM" && -n "$LOAD" && ${#ADDRS[@]} -gt 0 ]] || { echo "symbolicate.sh: --atos needs --dsym, --load and at least one address" >&2; exit 1; }
    atos -arch "$ARCH" -o "$(dwarf_binary "$DSYM")" -l "$LOAD" -i "${ADDRS[@]}" ;;
  report)
    [[ -n "$REPORT" && -f "$REPORT" ]] || { echo "symbolicate.sh: report file not found: '$REPORT'" >&2; usage 1; }
    case "$REPORT" in
      *.ips|*.crash) ;;
      *) # "Crash reports must have the .crash or .ips file extension ... rename the file before symbolicating."
        tmp="$(mktemp -d)/$(basename "$REPORT").ips"; cp "$REPORT" "$tmp"; REPORT="$tmp"
        echo "symbolicate.sh: copied report to $REPORT (needs a .ips/.crash extension)" >&2 ;;
    esac
    if [[ -n "$DSYM" ]]; then
      XCODE_DEV="$(xcode-select -p)"                      # .../Xcode.app/Contents/Developer
      RES="${XCODE_DEV%/Contents/Developer}/Contents/SharedFrameworks/CoreSymbolicationDT.framework/Resources"
      [[ -f "$RES/CrashSymbolicator.py" ]] || { echo "symbolicate.sh: CrashSymbolicator.py not found under $RES" >&2; exit 1; }
      REPORT_ABS="$(cd "$(dirname "$REPORT")" && pwd)/$(basename "$REPORT")"
      DSYM_ABS="$(cd "$(dirname "$DSYM")" && pwd)/$(basename "$DSYM")"
      if [[ -n "$OUT" ]]; then
        OUT_ABS="$(cd "$(dirname "$OUT")" 2>/dev/null && pwd || pwd)/$(basename "$OUT")"
        (cd "$RES" && python3 CrashSymbolicator.py "$REPORT_ABS" -d "$DSYM_ABS" -o "$OUT_ABS")
        echo "symbolicate.sh: wrote $OUT_ABS"
      else
        (cd "$RES" && python3 CrashSymbolicator.py "$REPORT_ABS" -d "$DSYM_ABS")
      fi
    else
      # Shortcut for lldb's crashlog Python module; finds dSYMs the way Xcode does.
      xcrun crashlog "$REPORT"
    fi ;;
esac

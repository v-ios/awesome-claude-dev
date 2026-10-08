#!/usr/bin/env bash
# scripts/xcresult-failures.sh — print failing tests, their messages, and export attachments only for
# failures from a .xcresult bundle, using the Xcode 16+ `xcresulttool get test-results ...` interface.
#
# composed: subcommand syntax is verbatim from xcresulttool(1) (research/notes/apple_platform_tooling.md §1);
# the JSON field names used in the jq filters below (testFailures, testNodes, nodeType, result, ...) come
# from `xcrun xcresulttool help get test-results summary|tests` on Xcode 16 — re-check them on your Xcode.
#
# Usage:
#   scripts/xcresult-failures.sh <path.xcresult> [--attachments DIR] [--console N] [--max N]
#     --attachments DIR   export attachments for failed tests only (default: <bundle>-attachments)
#     --console N         also print the last N lines of the console log (get log --type console)
#     --max N             cap on printed failure entries (default 50)
#
# Note: `xcrun xcresulttool get --format json --path X` is the legacy interface; on Xcode 16+ it errors
# unless `--legacy` is passed. This script only uses the new interface.
set -euo pipefail

usage() {
  sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-1}"
}

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "xcresult-failures.sh: xcresulttool requires macOS with Xcode; this host is $(uname -s)." >&2
    exit 1
  fi
}

[[ $# -ge 1 ]] || usage 1
case "$1" in -h|--help|help) usage 0 ;; esac
require_macos

BUNDLE="$1"; shift
[[ -d "$BUNDLE" ]] || { echo "xcresult-failures.sh: '$BUNDLE' is not a result bundle directory" >&2; exit 1; }
ATTACH_DIR=""
CONSOLE_LINES=0
MAX=50
while [[ $# -gt 0 ]]; do
  case "$1" in
    --attachments) ATTACH_DIR="$2"; shift 2 ;;
    --console) CONSOLE_LINES="$2"; shift 2 ;;
    --max) MAX="$2"; shift 2 ;;
    -h|--help) usage 0 ;;
    *) echo "xcresult-failures.sh: unknown option '$1'" >&2; usage 1 ;;
  esac
done
[[ -n "$ATTACH_DIR" ]] || ATTACH_DIR="${BUNDLE%.xcresult}-attachments"

have_jq() { command -v jq >/dev/null 2>&1; }

echo "== Summary: xcrun xcresulttool get test-results summary --path $BUNDLE --compact"
SUMMARY="$(xcrun xcresulttool get test-results summary --path "$BUNDLE" --compact)"
if have_jq; then
  printf '%s' "$SUMMARY" | jq -c '{result, totalTestCount, passedTests, failedTests, skippedTests, expectedFailures}'
  echo "== Failures (summary.testFailures)"
  # Print each failure object as one compact JSON line; field names inside are whatever your Xcode emits.
  printf '%s' "$SUMMARY" | jq -c '(.testFailures // [])[]' | head -n "$MAX"
  FAILED_COUNT="$(printf '%s' "$SUMMARY" | jq -r '.failedTests // 0')"
else
  printf '%s\n' "$SUMMARY" | head -c 4000; echo
  FAILED_COUNT="unknown"
fi

echo "== Failed test nodes: xcrun xcresulttool get test-results tests --path $BUNDLE --compact"
if have_jq; then
  # Walk the tree and print any node whose result is Failed (test plans, suites, cases and failure messages).
  xcrun xcresulttool get test-results tests --path "$BUNDLE" --compact \
    | jq -r '[.. | objects | select(.result? == "Failed" or .nodeType? == "Failure Message")]
             | .[] | "\(.nodeType // "?")\t\(.name // "")\t\(.nodeIdentifier // "")"' \
    | head -n "$MAX" || true
  echo "   (details for one test: xcrun xcresulttool get test-results test-details --path $BUNDLE --test-id <nodeIdentifier> --compact)"
else
  echo "   jq not installed; run the command above and inspect the JSON manually."
fi

if [[ "$FAILED_COUNT" != "0" ]]; then
  echo "== Attachments for failures -> $ATTACH_DIR"
  mkdir -p "$ATTACH_DIR"
  xcrun xcresulttool export attachments --path "$BUNDLE" --output-path "$ATTACH_DIR" --only-failures || true
  find "$ATTACH_DIR" -type f 2>/dev/null | head -n "$MAX" || true
fi

if [[ "$CONSOLE_LINES" -gt 0 ]]; then
  echo "== Console log (last $CONSOLE_LINES lines): xcrun xcresulttool get log --path $BUNDLE --type console"
  xcrun xcresulttool get log --path "$BUNDLE" --type console --compact 2>/dev/null | tail -n "$CONSOLE_LINES" || true
fi

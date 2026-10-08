#!/usr/bin/env bash
# scripts/xcb.sh — the one xcodebuild entry point for Claude Code sessions, hooks and CI.
#
# composed: assembled from the xcodebuild(1), xcbeautify and xcresulttool(1) syntax recorded in
# research/notes/apple_platform_tooling.md §1 and §3; validate in your repo before relying on it.
#
# Usage:
#   scripts/xcb.sh <build|test|build-for-testing|test-without-building> <ios|tvos>
#                  [--scheme S] [--only-testing T]... [--configuration C] [--xctestrun PATH]
#   scripts/xcb.sh destinations <ios|tvos>        # prints `xcodebuild -showdestinations` for the scheme
#   scripts/xcb.sh list                            # prints `xcodebuild -list`
#
# Environment (all optional, defaults shown):
#   SCHEME_IOS="MyApp"            SCHEME_TVOS="MyApp-tvOS"          <- placeholders; see INSTALL.md
#   WORKSPACE=""  (path/to/App.xcworkspace; wins over PROJECT)
#   PROJECT=""    (path/to/App.xcodeproj; auto-detected when exactly one *.xcodeproj is in the repo root)
#   DERIVED_DATA="./.derivedData"     XCRESULT_DIR="./build/xcresults"     CONFIGURATION="Debug"
#   SIM_IOS_NAME="iPhone 16"          SIM_TVOS_NAME="Apple TV 4K (3rd generation)"
#   XCB_CODE_SIGNING_ALLOWED="NO"     (set to "" to leave the SDK's own signing settings untouched)
#   XCB_NO_PACKAGE_RESOLUTION=0       (1 adds -disableAutomaticPackageResolution; Apple's CI guidance)
#   XCB_EXTRA_ARGS=""                 (extra xcodebuild arguments, word-split)
#   XCB_MAX_LINES=200                 (cap on filtered stdout when xcbeautify is not installed)
#
# Behaviour:
#   * destination = first available simulator named SIM_*_NAME (booted preferred), else the first
#     available iPhone / Apple TV, else `platform=... Simulator,name=SIM_*_NAME` (xcodebuild resolves it)
#   * -resultBundlePath is timestamped and deleted first (xcodebuild exits with an error if it exists)
#   * output goes through `xcbeautify --quiet` when installed, else a grep for error:/warning:/failed
#   * the raw log is kept next to the result bundle; tail it when the filtered output is not enough
#   * on test actions the xcresulttool summary and failing tests are printed
#   * .claude/last-build.json is written for .claude/hooks/session-start.sh and stop-gate.sh
#   * exits with xcodebuild's own status (pipefail-safe)
set -euo pipefail

usage() {
  sed -n '2,32p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-1}"
}

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "xcb.sh: xcodebuild requires macOS with Xcode; this host is $(uname -s). Nothing was run." >&2
    exit 1
  fi
}

# ---- defaults -------------------------------------------------------------------------------
SCHEME_IOS="${SCHEME_IOS:-MyApp}"
SCHEME_TVOS="${SCHEME_TVOS:-MyApp-tvOS}"
WORKSPACE="${WORKSPACE:-}"
PROJECT="${PROJECT:-}"
DERIVED_DATA="${DERIVED_DATA:-./.derivedData}"
XCRESULT_DIR="${XCRESULT_DIR:-./build/xcresults}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIM_IOS_NAME="${SIM_IOS_NAME:-iPhone 16}"
SIM_TVOS_NAME="${SIM_TVOS_NAME:-Apple TV 4K (3rd generation)}"
XCB_CODE_SIGNING_ALLOWED="${XCB_CODE_SIGNING_ALLOWED-NO}"
XCB_NO_PACKAGE_RESOLUTION="${XCB_NO_PACKAGE_RESOLUTION:-0}"
XCB_EXTRA_ARGS="${XCB_EXTRA_ARGS:-}"
XCB_MAX_LINES="${XCB_MAX_LINES:-200}"

[[ $# -ge 1 ]] || usage 1
case "$1" in -h|--help|help) usage 0 ;; esac
require_macos

ACTION="$1"; shift
PLATFORM="${1:-}"
case "$ACTION" in
  build|test|build-for-testing|test-without-building|destinations)
    [[ "$PLATFORM" == "ios" || "$PLATFORM" == "tvos" ]] || { echo "xcb.sh: platform must be ios or tvos" >&2; usage 1; }
    shift ;;
  list) ;;
  *) echo "xcb.sh: unknown action '$ACTION'" >&2; usage 1 ;;
esac

SCHEME=""
CONFIG_OVERRIDE=""
XCTESTRUN=""
ONLY_TESTING=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scheme) SCHEME="$2"; shift 2 ;;
    --only-testing) ONLY_TESTING+=("$2"); shift 2 ;;
    --configuration) CONFIG_OVERRIDE="$2"; shift 2 ;;
    --xctestrun) XCTESTRUN="$2"; shift 2 ;;
    -h|--help) usage 0 ;;
    *) echo "xcb.sh: unknown option '$1'" >&2; usage 1 ;;
  esac
done
[[ -n "$CONFIG_OVERRIDE" ]] && CONFIGURATION="$CONFIG_OVERRIDE"

# ---- container (workspace/project) ----------------------------------------------------------
container_args() {
  if [[ -n "$WORKSPACE" ]]; then
    printf '%s\n' -workspace "$WORKSPACE"
  elif [[ -n "$PROJECT" ]]; then
    printf '%s\n' -project "$PROJECT"
  else
    local found=()
    while IFS= read -r p; do found+=("$p"); done < <(ls -d ./*.xcodeproj 2>/dev/null || true)
    if [[ ${#found[@]} -eq 1 ]]; then
      printf '%s\n' -project "${found[0]}"
    fi
    # zero or several projects: let xcodebuild resolve (TN2339: -project is optional when unambiguous)
  fi
}

# bash 3.2 (macOS default) has no mapfile and errors on empty "${arr[@]}" under set -u,
# hence the read loop and the ${arr[@]+"${arr[@]}"} idiom below.
CARGS=()
while IFS= read -r a; do CARGS+=("$a"); done < <(container_args)

if [[ "$ACTION" == "list" ]]; then
  xcodebuild -list ${CARGS[@]+"${CARGS[@]}"}
  exit $?
fi

# ---- scheme / simulator per platform --------------------------------------------------------
if [[ "$PLATFORM" == "ios" ]]; then
  : "${SCHEME:=$SCHEME_IOS}"; SIM_NAME="$SIM_IOS_NAME"; PLATFORM_STR="iOS Simulator"
  RUNTIME_RE='SimRuntime\.iOS-'; FAMILY_RE='^iPhone'
else
  : "${SCHEME:=$SCHEME_TVOS}"; SIM_NAME="$SIM_TVOS_NAME"; PLATFORM_STR="tvOS Simulator"
  RUNTIME_RE='SimRuntime\.tvOS-'; FAMILY_RE='^Apple TV'
fi

# pick_udid <name> <family-regex> <runtime-regex>  (stdin: `xcrun simctl list devices available --json`)
pick_udid() {
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg name "$1" --arg fam "$2" --arg rt "$3" '
      [ .devices | to_entries[] | select(.key | test($rt)) | .value[] | select(.isAvailable == true) ]
      | ( (map(select(.name == $name)) | sort_by(.state != "Booted"))
        + (map(select(.name | test($fam))) | sort_by(.state != "Booted")) )
      | .[0].udid // empty'
  elif command -v python3 >/dev/null 2>&1; then
    python3 -I -c '
import json, re, sys
name, fam, rt = sys.argv[1:4]
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
devs = []
for runtime, lst in data.get("devices", {}).items():
    if re.search(rt, runtime):
        devs += [d for d in lst if d.get("isAvailable")]
for cand in ([d for d in devs if d.get("name") == name], [d for d in devs if re.search(fam, d.get("name", ""))]):
    cand.sort(key=lambda d: d.get("state") != "Booted")
    if cand:
        print(cand[0]["udid"]); break' "$1" "$2" "$3"
  fi
}

resolve_destination() {
  local udid=""
  udid="$(xcrun simctl list devices available --json 2>/dev/null | pick_udid "$SIM_NAME" "$FAMILY_RE" "$RUNTIME_RE" || true)"
  if [[ -n "$udid" ]]; then
    echo "platform=${PLATFORM_STR},id=${udid}"
  else
    echo "platform=${PLATFORM_STR},name=${SIM_NAME}"
  fi
}

if [[ "$ACTION" == "destinations" ]]; then
  xcodebuild -showdestinations ${CARGS[@]+"${CARGS[@]}"} -scheme "$SCHEME"
  exit $?
fi

DESTINATION="$(resolve_destination)"

# ---- result bundle + log --------------------------------------------------------------------
mkdir -p "$XCRESULT_DIR" "$DERIVED_DATA" .claude
STAMP="$(date +%Y%m%d-%H%M%S)"
BUNDLE="${XCRESULT_DIR}/${SCHEME}-${ACTION}-${PLATFORM}-${STAMP}.xcresult"
LOG="${BUNDLE%.xcresult}.log"
# xcodebuild: "If the path already exists, xcodebuild will exit with an error."
[[ -e "$BUNDLE" ]] && rm -rf "$BUNDLE"

# ---- assemble xcodebuild args ---------------------------------------------------------------
ARGS=()
if [[ "$ACTION" == "test-without-building" && -n "$XCTESTRUN" ]]; then
  ARGS+=(-xctestrun "$XCTESTRUN")          # man page: with -xctestrun the bundles come from the file, no scheme
else
  ARGS+=(${CARGS[@]+"${CARGS[@]}"} -scheme "$SCHEME")
fi
ARGS+=(-destination "$DESTINATION"
       -derivedDataPath "$DERIVED_DATA"
       -resultBundlePath "$BUNDLE"
       -configuration "$CONFIGURATION"      # composed: standard xcodebuild option, not quoted in the notes
       -skipPackagePluginValidation
       -skipMacroValidation
       -quiet)
[[ "$XCB_NO_PACKAGE_RESOLUTION" == "1" ]] && ARGS+=(-disableAutomaticPackageResolution)
for t in ${ONLY_TESTING[@]+"${ONLY_TESTING[@]}"}; do
  ARGS+=("-only-testing:${t}")   # identifier form: TestTarget[/TestClass[/TestMethod]]
done
if [[ -n "$XCB_EXTRA_ARGS" ]]; then
  # shellcheck disable=SC2206
  EXTRA=($XCB_EXTRA_ARGS); ARGS+=("${EXTRA[@]}")
fi
ARGS+=("$ACTION")
# Simulator builds need no signing. Caveat (CircleCI thread in the notes): overriding signing settings can
# surface as exit 65 in some UI-test setups; set XCB_CODE_SIGNING_ALLOWED="" to drop the override.
if [[ -n "$XCB_CODE_SIGNING_ALLOWED" ]]; then
  ARGS+=("CODE_SIGNING_ALLOWED=${XCB_CODE_SIGNING_ALLOWED}")
fi

# ---- output filter --------------------------------------------------------------------------
FILTER=()
if command -v xcbeautify >/dev/null 2>&1; then
  FILTER=(xcbeautify --quiet --disable-logging)
  case "$ACTION" in test|test-without-building) FILTER+=(--is-ci) ;; esac
  [[ "${GITHUB_ACTIONS:-}" == "true" ]] && FILTER+=(--renderer github-actions)
else
  FILTER=(bash -c 'grep -E "error:|warning:|failed|FAILED|SUCCEEDED|Test Case|Test Suite|Executed" || true')
fi

echo "xcb.sh: $ACTION $PLATFORM scheme=$SCHEME config=$CONFIGURATION destination='$DESTINATION'"
echo "xcb.sh: result bundle $BUNDLE (raw log: $LOG)"

set +e
NSUnbufferedIO=YES xcodebuild "${ARGS[@]}" 2>&1 | tee "$LOG" | "${FILTER[@]}" | tail -n "$XCB_MAX_LINES"
STATUS=${PIPESTATUS[0]}
set -e

# ---- test summary ---------------------------------------------------------------------------
if [[ "$ACTION" == "test" || "$ACTION" == "test-without-building" ]] && [[ -d "$BUNDLE" ]]; then
  echo "xcb.sh: test summary (xcrun xcresulttool get test-results summary --path ... --compact)"
  if command -v jq >/dev/null 2>&1; then
    xcrun xcresulttool get test-results summary --path "$BUNDLE" --compact 2>/dev/null \
      | jq -c '{result, totalTestCount, passedTests, failedTests, skippedTests, expectedFailures}' || true
  else
    xcrun xcresulttool get test-results summary --path "$BUNDLE" --compact 2>/dev/null | head -c 2000 || true
    echo
  fi
  if [[ "$STATUS" -ne 0 ]]; then
    HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -x "$HERE/xcresult-failures.sh" ]]; then
      "$HERE/xcresult-failures.sh" "$BUNDLE" || true
    fi
  fi
fi

# ---- status file for the SessionStart / Stop hooks ------------------------------------------
FINISHED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if command -v jq >/dev/null 2>&1; then
  jq -n --arg action "$ACTION" --arg platform "$PLATFORM" --arg scheme "$SCHEME" \
        --arg configuration "$CONFIGURATION" --arg destination "$DESTINATION" \
        --argjson status "$STATUS" --arg bundle "$BUNDLE" --arg log "$LOG" --arg finished "$FINISHED" \
        '{action:$action, platform:$platform, scheme:$scheme, configuration:$configuration,
          destination:$destination, status:$status, result_bundle:$bundle, log:$log, finished_at:$finished}' \
        > .claude/last-build.json
else
  printf '{"action":"%s","platform":"%s","scheme":"%s","configuration":"%s","status":%s,"result_bundle":"%s","log":"%s","finished_at":"%s"}\n' \
    "$ACTION" "$PLATFORM" "$SCHEME" "$CONFIGURATION" "$STATUS" "$BUNDLE" "$LOG" "$FINISHED" > .claude/last-build.json
fi

if [[ "$STATUS" -eq 0 ]]; then
  echo "xcb.sh: $ACTION $PLATFORM OK"
else
  echo "xcb.sh: $ACTION $PLATFORM FAILED (xcodebuild exit $STATUS). Raw log: $LOG" >&2
fi
exit "$STATUS"

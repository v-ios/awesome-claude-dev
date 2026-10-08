#!/usr/bin/env bash
# scripts/sim.sh — `xcrun simctl` helpers that are Apple TV aware.
#
# composed: the simctl subcommand forms come from research/notes/apple_platform_tooling.md §2
# (MobileBuildMCP source, ios-simulator-mcp, third-party skill docs). Apple publishes no web page for
# simctl; verify any flag with `xcrun simctl help <subcommand>` on your Xcode.
#
# Usage:
#   scripts/sim.sh [--device <udid|name|ios|tvos|booted>] <command> [args]
#
#   list [ios|tvos]                           available devices as JSON (xcrun simctl list devices available --json)
#   devicetypes                               xcrun simctl list devicetypes   (device names change per Xcode)
#   boot                                      boot the target device and wait (bootstatus -b)
#   install <path/to/App.app>
#   uninstall <bundle-id>
#   launch <bundle-id> [--console] [--env K=V]... [-- <app args>]
#   terminate <bundle-id>
#   screenshot [out.png]                      default: ./build/screenshots/<device>-<stamp>.png
#   record [out.mp4]                          xcrun simctl io <udid> recordVideo ... (Ctrl+C stops)
#   openurl <url>
#   push <bundle-id> <payload.json>           payload: top-level JSON object with an "aps" dict
#   privacy <grant|revoke|reset> <service> <bundle-id>
#   status_bar <clear | override --time "9:41" ...>
#   appearance <light|dark>
#   log <NSPredicate> [--last 2m]             xcrun simctl spawn <udid> log stream --predicate '...'
#                                             (with --last N it runs `log show --last N` instead: --last is a show option)
#   shutdown | erase | app-container <bundle-id>
#
# Environment: SIM_IOS_NAME="iPhone 16"  SIM_TVOS_NAME="Apple TV 4K (3rd generation)"  SIM_TARGET=booted
#
# tvOS input notes (Device Hub, Xcode 26/27): Left/Right/Up/Down arrows move focus, Return triggers the
# focused item, Escape goes up one level; Xcode 27 removed the virtual Siri Remote. For scripted input use
# `idb ui remote up|down|left|right|select|menu` (facebook/idb) or MobileBuildMCP `key_press` with HID codes
# 82/81/80/79 (arrows), 40 (Return), 41 (Escape). simctl itself has no remote-input subcommand.
set -euo pipefail

usage() {
  sed -n '2,32p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-1}"
}

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "sim.sh: xcrun simctl requires macOS with Xcode; this host is $(uname -s). Nothing was run." >&2
    exit 1
  fi
}

SIM_IOS_NAME="${SIM_IOS_NAME:-iPhone 16}"
SIM_TVOS_NAME="${SIM_TVOS_NAME:-Apple TV 4K (3rd generation)}"
TARGET="${SIM_TARGET:-booted}"

[[ $# -ge 1 ]] || usage 1
case "$1" in -h|--help|help) usage 0 ;; esac
require_macos

if [[ "$1" == "--device" ]]; then
  [[ $# -ge 2 ]] || usage 1
  TARGET="$2"; shift 2
fi
[[ $# -ge 1 ]] || usage 1
CMD="$1"; shift

# ---- device resolution ----------------------------------------------------------------------
# pick_udid <name> <family-regex> <runtime-regex>; stdin is the simctl JSON
pick_udid() {
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg name "$1" --arg fam "$2" --arg rt "$3" '
      [ .devices | to_entries[] | select(.key | test($rt)) | .value[] | select(.isAvailable == true) ]
      | ( (map(select(.name == $name)) | sort_by(.state != "Booted"))
        + (map(select(.name | test($fam))) | sort_by(.state != "Booted")) )
      | .[0].udid // empty'
  else
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

resolve_udid() {
  case "$TARGET" in
    booted) echo "booted" ;;                       # simctl's own keyword
    ios)  xcrun simctl list devices available --json | pick_udid "$SIM_IOS_NAME"  '^iPhone'   'SimRuntime\.iOS-' ;;
    tvos) xcrun simctl list devices available --json | pick_udid "$SIM_TVOS_NAME" '^Apple TV' 'SimRuntime\.tvOS-' ;;
    *)
      if [[ "$TARGET" =~ ^[0-9A-Fa-f-]{36}$ ]]; then
        echo "$TARGET"
      else # a device name
        xcrun simctl list devices available --json | pick_udid "$TARGET" "^${TARGET}\$" 'SimRuntime\.'
      fi ;;
  esac
}

UDID="$(resolve_udid)"
if [[ -z "$UDID" ]]; then
  echo "sim.sh: no available simulator matches '$TARGET'. Try: scripts/sim.sh list, scripts/sim.sh devicetypes" >&2
  exit 1
fi

case "$CMD" in
  list)
    plat="${1:-}"
    case "$plat" in
      ios)  xcrun simctl list devices available --json | { command -v jq >/dev/null 2>&1 && jq '{devices: (.devices | with_entries(select(.key | test("SimRuntime\\.iOS-"))))}' || cat; } ;;
      tvos) xcrun simctl list devices available --json | { command -v jq >/dev/null 2>&1 && jq '{devices: (.devices | with_entries(select(.key | test("SimRuntime\\.tvOS-"))))}' || cat; } ;;
      *)    xcrun simctl list devices available --json ;;
    esac ;;
  devicetypes) xcrun simctl list devicetypes ;;
  boot)
    if [[ "$UDID" == "booted" ]]; then echo "sim.sh: --device booted is ambiguous for boot; pass ios, tvos, a name or a udid" >&2; exit 1; fi
    xcrun simctl boot "$UDID" 2>/dev/null || true     # already booted is not an error for us
    xcrun simctl bootstatus "$UDID" -b
    echo "sim.sh: booted $UDID" ;;
  install)   [[ $# -ge 1 ]] || usage 1; xcrun simctl install "$UDID" "$1" ;;
  uninstall) [[ $# -ge 1 ]] || usage 1; xcrun simctl uninstall "$UDID" "$1" ;;
  launch)
    [[ $# -ge 1 ]] || usage 1
    bundle="$1"; shift
    console=0; appargs=()
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --console) console=1; shift ;;
        --env) # simctl launch has no --env on all Xcode versions; SIMCTL_CHILD_<VAR> is forwarded to the app
          export "SIMCTL_CHILD_${2}"; shift 2 ;;
        --) shift; appargs=("$@"); break ;;
        *) appargs+=("$1"); shift ;;
      esac
    done
    # composed: extra positional arguments are passed to the app as launch arguments
    # (e.g. -UIFocusLoggingEnabled YES); Apple documents that flag via the scheme's "Arguments Passed On Launch".
    if [[ "$console" -eq 1 ]]; then
      xcrun simctl launch --console-pty --terminate-running-process "$UDID" "$bundle" ${appargs[@]+"${appargs[@]}"}
    else
      xcrun simctl launch --terminate-running-process "$UDID" "$bundle" ${appargs[@]+"${appargs[@]}"}
    fi ;;
  terminate) [[ $# -ge 1 ]] || usage 1; xcrun simctl terminate "$UDID" "$1" ;;
  screenshot)
    out="${1:-}"
    if [[ -z "$out" ]]; then mkdir -p ./build/screenshots; out="./build/screenshots/${UDID}-$(date +%Y%m%d-%H%M%S).png"; fi
    xcrun simctl io "$UDID" screenshot "$out"
    echo "$out" ;;
  record)
    out="${1:-./build/screenshots/${UDID}-$(date +%Y%m%d-%H%M%S).mp4}"
    mkdir -p "$(dirname "$out")"
    echo "sim.sh: recording to $out (Ctrl+C to stop)"
    xcrun simctl io "$UDID" recordVideo "$out" ;;
  openurl)   [[ $# -ge 1 ]] || usage 1; xcrun simctl openurl "$UDID" "$1" ;;
  push)      [[ $# -ge 2 ]] || usage 1; xcrun simctl push "$UDID" "$1" "$2" ;;
  privacy)   [[ $# -ge 3 ]] || usage 1; xcrun simctl privacy "$UDID" "$1" "$2" "$3" ;;
  status_bar) [[ $# -ge 1 ]] || usage 1; xcrun simctl status_bar "$UDID" "$@" ;;
  appearance) [[ $# -ge 1 ]] || usage 1; xcrun simctl ui "$UDID" appearance "$1" ;;
  log)
    [[ $# -ge 1 ]] || usage 1
    pred="$1"; shift
    # os.Logger output is not on the app's stdout; it only shows up through `log stream` / `log show`.
    # `--last num[s|m|h|d]` is a `log show` option, so switch subcommand when it is requested.
    mode="stream"
    for a in "$@"; do [[ "$a" == "--last" ]] && mode="show"; done
    xcrun simctl spawn "$UDID" log "$mode" --predicate "$pred" "$@" ;;
  shutdown)  xcrun simctl shutdown "$UDID" ;;
  erase)     xcrun simctl erase "$UDID" ;;
  app-container) [[ $# -ge 1 ]] || usage 1; xcrun simctl get_app_container "$UDID" "$1" app ;;
  *) echo "sim.sh: unknown command '$CMD'" >&2; usage 1 ;;
esac

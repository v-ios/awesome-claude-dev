#!/usr/bin/env bash
# .claude/hooks/protect-files.sh — PreToolUse hook for Edit|Write|MultiEdit.
# Blocks edits to generated / locked / signing files with exit 2 (stderr becomes the reason Claude sees).
# Shape follows the official protect-files.sh example (hooks guide) quoted in
# research/notes/governance_and_context_engineering.md KQ3; the pattern list is from the composed Swift hook set there.
#
# Override for one deliberate, human-approved edit:  CLAUDE_ALLOW_PROTECTED_EDITS=1 claude
# Note: `.claude/settings.json` deny rules (Edit(**/*.pbxproj) ...) are the first line; this hook is the second,
# and it also covers Write/MultiEdit payloads. Neither sees `sed -i` run through Bash — the sandbox does.
set -euo pipefail

INPUT="$(cat)"

# json_get <dotted.path>: jq when available, python3 fallback (jq is listed as a prerequisite in INSTALL.md)
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

if [[ "${CLAUDE_ALLOW_PROTECTED_EDITS:-0}" == "1" ]]; then
  exit 0
fi

FILE_PATH="$(json_get tool_input.file_path)"
[[ -n "$FILE_PATH" ]] || exit 0
# Normalize Windows backslash separators so the patterns below match
FILE_PATH="${FILE_PATH//\\//}"

case "$FILE_PATH" in
  *.pbxproj|*.xcworkspacedata)
    echo "Blocked: $FILE_PATH is a generated Xcode project file. Edit project.yml (XcodeGen) / Project.swift (Tuist) and regenerate, or ask the user to make the change in Xcode. See .claude/rules/xcode-project.md" >&2
    exit 2 ;;
  */Podfile.lock|Podfile.lock|*/Package.resolved|Package.resolved)
    echo "Blocked: $FILE_PATH is a lockfile. Regenerate it with the tool (pod install / xcodebuild -resolvePackageDependencies / swift package resolve) after the user approves the dependency change. See .claude/rules/xcode-project.md" >&2
    exit 2 ;;
  *.entitlements|*.mobileprovision|*.p12|*.p8|*.cer|*.certSigningRequest)
    echo "Blocked: $FILE_PATH is a signing/entitlements file. Signing changes need human sign-off (CLAUDE.md > Needs human sign-off)." >&2
    exit 2 ;;
  */GoogleService-Info.plist|GoogleService-Info.plist|*/.env|.env|*/.env.*|.env.*|*/.git/*|.git/*)
    echo "Blocked: $FILE_PATH is a secret or repository-internal file; Claude must not read or write it." >&2
    exit 2 ;;
esac

exit 0

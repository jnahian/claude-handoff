#!/bin/bash
# Usage: finish.sh <handoff-doc-path> [session-id]
# Registers the handoff for the next fresh session in this project and, in
# iTerm2, opens a new tab with a fresh Claude Code session.

. "$(dirname "$0")/lib.sh"

doc="$1"
sid=$(safe_id "${2:-}")

if [ ! -s "$doc" ]; then
  echo "ERROR: handoff document missing or empty: $doc"
  exit 1
fi

root=$(project_root "$PWD")
key=$(project_key "$root")
printf '%s\n' "$doc" > "$PENDING_DIR/$key"
[ -n "$sid" ] && touch "$STATE_DIR/$sid.requested"

launched=0
if [ "$AUTO_LAUNCH" = "1" ] && [ "$TERM_PROGRAM" = "iTerm.app" ] && command -v osascript >/dev/null 2>&1; then
  if osascript - "$root" >/dev/null 2>&1 <<'APPLESCRIPT'
on run argv
  set projectDir to item 1 of argv
  set cmd to "cd " & quoted form of projectDir & " && claude " & quoted form of "Resume from the handoff document."
  tell application "iTerm2"
    tell current window
      create tab with default profile
      tell current session to write text cmd
    end tell
  end tell
end run
APPLESCRIPT
  then
    launched=1
  fi
fi

if [ "$launched" = 1 ]; then
  echo "RESULT=LAUNCHED"
  echo "A new iTerm2 tab was opened with a fresh session. This tab can be closed."
else
  echo "RESULT=MANUAL"
  echo "No tab was opened (terminal: ${TERM_PROGRAM:-unknown}). Tell the user to type /clear, then send 'resume'."
fi
echo "Handoff registered for: $root (valid for ${PENDING_TTL_MIN} minutes)"

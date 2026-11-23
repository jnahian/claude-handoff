#!/bin/bash
# SessionStart hook. On a fresh session (startup or /clear), if a recent handoff
# exists for this project, point Claude at it and consume it.

. "$(dirname "$0")/lib.sh"

input=$(cat)
sid=$(safe_id "$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)")
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
src=$(printf '%s' "$input" | jq -r '.source // "startup"' 2>/dev/null)

case "$src" in startup|clear) ;; *) exit 0 ;; esac

# Fresh context: reset this session's markers, prune old state.
[ -n "$sid" ] && rm -f "$STATE_DIR/$sid.requested" "$STATE_DIR/$sid.owed"
find "$STATE_DIR" "$PENDING_DIR" -type f -mtime +7 -delete 2>/dev/null

key=$(project_key "$(project_root "${cwd:-$PWD}")")
pending="$PENDING_DIR/$key"
pending_fresh "$key" || exit 0

doc=$(head -n 1 "$pending")
rm -f "$pending"                      # consume: offered to exactly one session
[ -s "$doc" ] || exit 0

ctx="HANDOFF AVAILABLE: a previous session in this project wrote a handoff document at:
$doc

Before anything else:
1. Read that file in full.
2. Check its 'Files and git state' section against the real repo (git status, current branch). Report any mismatch.
3. Reply with at most 10 lines: the goal, where things stand, and the single next step you would take.
4. Then WAIT. Do not edit files or run state-changing commands until the user says to go.

If the user's first message is clearly about something unrelated, mention in one line that this handoff exists and ask whether to resume it or ignore it."

jq -n --arg c "$ctx" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'

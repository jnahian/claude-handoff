#!/bin/bash
# Stop hook. When the context reaches THRESHOLD_TOKENS, tell Claude to finish the
# running task and then hand off. Asks again on later turns until that happens:
# finish.sh writes the .requested marker, so a deferred handoff is never lost.

. "$(dirname "$0")/lib.sh"

input=$(cat)
sid=$(safe_id "$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)")
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)

[ -z "$sid" ] && exit 0
[ "$active" = "true" ] && exit 0                 # already continuing from a stop hook
[ -f "$STATE_DIR/$sid.requested" ] && exit 0     # already handed off

# Context size of the last main-thread API call. fromjson? skips a line still being written.
tokens=$(tail -n 400 "$transcript" 2>/dev/null |
  jq -R -r 'fromjson? | select(.type == "assistant" and .message.usage != null and .message.model != "<synthetic>" and (.isSidechain | not))
    | .message.usage | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)' 2>/dev/null |
  tail -n 1)
case "$tokens" in ''|*[!0-9]*) tokens=0 ;; esac

why=""
if [ "$tokens" -ge "$THRESHOLD_TOKENS" ]; then
  why="Context is at $tokens tokens (handoff threshold: $THRESHOLD_TOKENS)."
elif [ -f "$STATE_DIR/$sid.owed" ]; then
  why="This session was auto-compacted before a handoff could be written."
else
  exit 0
fi

# After a compaction, Claude only holds a summary: point it at the full transcript.
[ -f "$STATE_DIR/$sid.owed" ] && [ -s "$transcript" ] &&
  why="$why Your context is now a summary. The full transcript, from before the compaction, is at $transcript: when writing the handoff, search it as the skill describes."

# These always end and wake the session, so wait quietly. Shells, monitors and
# teammates can live forever: Claude judges those from the message below.
printf '%s' "$input" |
  jq -e 'any(.background_tasks[]?; .type == "subagent" or .type == "workflow")' >/dev/null 2>&1 &&
  exit 0

# A handoff for this project was just written (for example by a manual /handoff).
key=$(project_key "$(project_root "${cwd:-$PWD}")")
if pending_fresh "$key"; then
  touch "$STATE_DIR/$sid.requested"
  exit 0
fi

reason="$why A handoff is due, but the running task comes first. This is an automated check, not a reply or approval from the user.
- Task unfinished and you can continue: finish the steps the user already asked for, then invoke the handoff skill.
- Waiting on background work for the task, or on the user's answer to a question or proposal: do not hand off and do not assume an answer. End the turn with one line saying what you are waiting for, repeating any question. You will be reminded again.
- Task finished: invoke the handoff skill now (Skill tool, skill name: handoff:handoff) and follow it exactly. A dev server or watcher left running does not make a task unfinished.
Do not start a different task. If the user declined the handoff, or the skill cannot run and you wrote the document by hand, run this instead: touch '$STATE_DIR/$sid.requested'"

jq -n --arg r "$reason" '{decision: "block", reason: $r}'

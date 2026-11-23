#!/bin/bash
# PreCompact hook (auto only). If auto-compaction arrives before a handoff was
# written, mark the session so the next Stop requests one even though the context
# is small again after compaction.

. "$(dirname "$0")/lib.sh"

input=$(cat)
sid=$(safe_id "$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)")
trigger=$(printf '%s' "$input" | jq -r '.trigger // "auto"' 2>/dev/null)

if [ -n "$sid" ] && [ "$trigger" = "auto" ] && [ ! -f "$STATE_DIR/$sid.requested" ]; then
  touch "$STATE_DIR/$sid.owed"
fi
exit 0

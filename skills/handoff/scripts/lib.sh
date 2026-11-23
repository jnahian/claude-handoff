#!/bin/bash
# Shared helpers for the handoff plugin. Sourced by every script.

HANDOFF_HOME="${HANDOFF_HOME:-$HOME/.claude/handoff}"
STATE_DIR="$HANDOFF_HOME/state"
PENDING_DIR="$HANDOFF_HOME/pending"

# Defaults. Override in $HANDOFF_HOME/config.sh.
THRESHOLD_TOKENS=500000            # context tokens at or above which a handoff is requested
PENDING_TTL_MIN=120                # a written handoff is offered to new sessions for this long
AUTO_LAUNCH=1                      # 1 = open a new iTerm2 tab after writing the handoff
DOCS_DIR="$HOME/.claude/handoffs"  # documents go in $DOCS_DIR/<project>/

# shellcheck disable=SC1091
[ -f "$HANDOFF_HOME/config.sh" ] && . "$HANDOFF_HOME/config.sh"

mkdir -p "$STATE_DIR" "$PENDING_DIR"

# Git toplevel if inside a repo, otherwise the physical directory.
project_root() {
  local d="${1:-$PWD}"
  git -C "$d" rev-parse --show-toplevel 2>/dev/null && return
  (cd "$d" 2>/dev/null && pwd -P) || printf '%s\n' "$d"
}

# Stable filename-safe key for a project root.
project_key() {
  printf '%s' "$1" | cksum | awk '{print $1 "-" $2}'
}

safe_id() {
  printf '%s' "$1" | tr -cd 'A-Za-z0-9_-'
}

# Age of a file in minutes. GNU stat first: on Linux the BSD form prints junk.
file_age_min() {
  local m
  m=$(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0)
  echo $(( ($(date +%s) - m) / 60 ))
}

# True if an unconsumed, unexpired handoff exists for this project key.
pending_fresh() {
  local f="$PENDING_DIR/$1"
  [ -f "$f" ] && [ "$(file_age_min "$f")" -lt "$PENDING_TTL_MIN" ]
}

#!/bin/bash
# Usage: new-handoff.sh <short-slug>
# Prints the path to write the handoff document to, plus a git snapshot.
# Documents go in $DOCS_DIR/<project>/ (set in config.sh, default ~/.claude/handoffs).

. "$(dirname "$0")/lib.sh"

slug=$(printf '%s' "${1:-session}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//' | cut -c1-40)
[ -z "$slug" ] && slug="session"

root=$(project_root "$PWD")
dir="$DOCS_DIR/$(basename "$root")"
mkdir -p "$dir"
git -C "$root" rev-parse --git-dir >/dev/null 2>&1 && in_git=1 || in_git=0

echo "HANDOFF_PATH=$dir/$(date +%Y%m%d-%H%M)-$slug.md"
echo "PROJECT_ROOT=$root"
echo
if [ "$in_git" = 1 ]; then
  echo "--- git snapshot ---"
  echo "branch: $(git -C "$root" branch --show-current 2>/dev/null)"
  echo "head:   $(git -C "$root" log -1 --format='%h %s' 2>/dev/null)"
  echo "status:"
  git -C "$root" status --short 2>/dev/null | head -n 60
  echo "diff stat (unstaged + staged vs HEAD):"
  git -C "$root" diff HEAD --stat 2>/dev/null | tail -n 30
  echo "recent commits:"
  git -C "$root" log -5 --format='  %h %s' 2>/dev/null
else
  echo "--- not a git repository ---"
fi

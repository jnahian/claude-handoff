# handoff

A Claude Code plugin that hands a long session to a fresh one. When the context
gets large, Claude finishes the task at hand, writes a handoff document (goal,
state, decisions, dead ends, next steps), and the next session starts from it.
You keep a full-detail record instead of a compaction summary.

## Install

At the prompt of a Claude Code terminal session:

```
/plugin install handoff --marketplace jnahian/claude-handoff
```

Answer `y` to add the marketplace, then pick a scope (user scope makes it work
in every project). From a shell instead:

```
claude plugin install handoff --marketplace jnahian/claude-handoff
```

In the desktop app, where `/plugin` does not run: click + next to the prompt
box, then Plugins, Add marketplace with `jnahian/claude-handoff`, then Add plugin.

Requires `bash` and `jq` (`brew install jq`). Opening the next session in a new
tab works in iTerm2 on macOS; elsewhere you type `/clear` and send `resume`.

### Recommended: turn off idle compaction

Claude Code compacts a session that holds 200k tokens or more once it has been
idle for about 55 minutes, just before the prompt cache expires. That usually
happens before the handoff threshold is reached, so the handoff never gets the
chance to run. Add this to `~/.claude/settings.json`:

```json
"idleCompaction": false
```

The cost: the first message after an hour away re-reads the whole context
without the cache.

## How it works

| Piece | File | Job |
|---|---|---|
| Stop hook | `stop-hook.sh` | At the end of a turn, if the context is at or above the threshold, tells Claude to finish the running task, then run the skill (asks again until it has) |
| PreCompact hook | `precompact-hook.sh` | If auto-compaction arrives first, marks the session so the next stop still asks for a handoff, pointing Claude at the full transcript |
| Skill | `skills/handoff/SKILL.md` | Writes the document; also runs on demand as `/handoff:handoff` |
| Finish script | `finish.sh` | Registers the document and, in iTerm2, opens a new tab with a fresh session |
| SessionStart hook | `sessionstart-hook.sh` | In the fresh session, points Claude at the document; Claude restates the plan and waits |

The context size is read from the session transcript (the token count of the
last API call), so no status line is needed.

## Settings

Create `~/.claude/handoff/config.sh` to change any of these:

```bash
THRESHOLD_TOKENS=500000            # context tokens that trigger a handoff
PENDING_TTL_MIN=120                # minutes a handoff waits for a new session
AUTO_LAUNCH=1                      # 0 = never open a tab, always use /clear
DOCS_DIR="$HOME/.claude/handoffs"  # documents go in $DOCS_DIR/<project>/
```

Use `$HOME` in paths, not a quoted `~`. The default threshold suits 1M-token
context windows. On a 200k window it is never reached, so set it to around
`150000` there.

## Where things go

- Handoff documents: `$DOCS_DIR/<project>/<date>-<slug>.md`, where `<project>`
  is the git repo's folder name (each git worktree gets its own).
- Session markers and pending handoffs: `~/.claude/handoff/state/` and
  `~/.claude/handoff/pending/`.

## Known limits

- The check runs at the end of a turn, not mid-turn.
- The handoff waits for the running task, so the context can pass the threshold.
  It waits silently for subagents and workflows; when the task waits on you or on
  a background shell, Claude adds one line saying so. `/handoff:handoff` runs
  immediately.
- A handoff is consumed by the first fresh session in the same project folder.
  If that session is about something else, Claude asks whether to resume or
  ignore it.

## Uninstall

```
/plugin uninstall handoff
```

This leaves `~/.claude/handoff/` (settings and markers) and your handoff
documents in place; delete them by hand if you want them gone.

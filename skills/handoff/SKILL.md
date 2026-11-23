---
name: handoff
description: Write a handoff document for the current work and start a fresh Claude Code session from it. Use when the user types /handoff or /handoff:handoff, asks to hand off or restart with fresh context, or when a Stop hook reports that a handoff is due and the running task is finished (never in the middle of a task).
argument-hint: "[optional note to include]"
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/new-handoff.sh *), Bash(${CLAUDE_SKILL_DIR}/scripts/finish.sh *), Write, Read
---

# Handoff

Move the current work into a fresh session with clean context. You write one
document that a new session, which remembers nothing of this one, can act on.

Extra note from the user, if any: $ARGUMENTS

## When to run

- The user asked: run now, even mid-task.
- A Stop hook asked: run only once the running task is finished. If work remains,
  or you are waiting on background work or the user's answer, do not run these
  steps yet: follow the hook's message.

## Steps

1. Pick a 2 to 4 word slug for the task (for example `token-migration-retry`) and run:

   ```
   ${CLAUDE_SKILL_DIR}/scripts/new-handoff.sh <slug>
   ```

   It prints `HANDOFF_PATH=...` and a git snapshot. Use that exact path.

2. Write the handoff document to `HANDOFF_PATH` using the template below.

3. Register it and launch the next session:

   ```
   ${CLAUDE_SKILL_DIR}/scripts/finish.sh "<HANDOFF_PATH>" "${CLAUDE_SESSION_ID}"
   ```

4. Tell the user, in three lines or fewer: the document path, and what happens
   next based on the script output.
   - `RESULT=LAUNCHED`: a new terminal tab has a fresh session; this one can be closed.
   - `RESULT=MANUAL`: type `/clear`, then send `resume`.

5. Stop. Do not continue the task in this session.

## Writing rules

The reader has zero context. A vague handoff is worse than none because the
next session will act on it confidently.

- Be specific: file paths with line references, function names, exact commands,
  error messages verbatim. No "the auth bug" or "the file we discussed".
- Separate what is **verified** (you ran it, you saw it) from what is **assumed**.
- State constraints and preferences the user gave in this session, in their words.
- Record decisions with the reason, so they are not relitigated.
- Record dead ends with why they failed, so they are not retried.
- Do not narrate the conversation. Do not include secrets, tokens, or `.env` values.
- Next steps are ordered and concrete. The first one must be doable immediately.
- If something is unknown, write "unknown". Do not fill gaps with guesses.
- Aim for under 150 lines. Link to files instead of pasting large code blocks.
- If the session was compacted, your memory of the earlier work is a lossy
  summary. When a Stop hook names the transcript from before the compaction (a
  JSONL file, often megabytes), search it, never read it whole: `grep` it for
  the exact paths, commands and errors you need, and pull the user's own words
  (without the compaction summary or harness wrappers) with:

  ```
  jq -r 'select(.type=="user" and (.message.content|type)=="string" and (.isCompactSummary|not) and (.isMeta|not) and (.message.content|test("^<(local-command|command-|task-notification|system-reminder)")|not)) | .timestamp[0:16] + " " + (.message.content | if length > 800 then .[0:500] + " [...] " + .[-300:] else . end)' <path>
  ```

  List the path under Files and git state.

## Template

```markdown
# Handoff: <task title>

Written: <date and time> | Branch: <branch> | Reason: <threshold reached | compacted | manual>

## Goal
What the user wants, and what "done" looks like.

## Current state
- Done: ...
- In progress: ... (exactly where it stopped)
- Not started: ...

## Decisions and rationale
- <decision>: <why>. Alternatives rejected: <which and why>.

## User constraints and preferences
- ...

## Files and git state
- Branch and HEAD: ...
- Uncommitted changes: <file>: <what changed and why>
- Key files to read first: <path>: <what is in it>
- Commands to verify the current state: <test, build, run commands and their last known result>
- Pre-compaction transcript: <path, or none>

## Dead ends
- Tried <approach>: failed because <reason>. Do not retry unless <condition>.

## Open questions
- ... (who can answer: user | code | docs)

## Next steps
1. ...
2. ...
```

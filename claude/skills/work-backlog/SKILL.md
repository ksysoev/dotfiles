---
name: work-backlog
description: Work through a repo's GitHub issue backlog, or one milestone of it, in a loop. Each issue runs /implement-issue in its own new background Claude Code session and git worktree, one at a time or several in parallel, in dependency order. Blocked issues wait until their blockers are merged. Use when the user asks to work, burn down or implement a backlog, a milestone, or "all open issues".
argument-hint: "[owner/repo] [--milestone <title>] [--parallel <n>] [--rounds <n>]"
disable-model-invocation: true
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/*) Bash(gh issue view *) Bash(gh issue list *) Bash(gh pr list *) Bash(gh pr view *) Bash(gh repo view *) Bash(claude agents *) Bash(claude logs *) Bash(claude rm *) Bash(git rev-parse *) Bash(git remote *) Bash(git worktree list *) Bash(git status *)
---

# Work a GitHub backlog in a loop

Arguments: `$ARGUMENTS`

Parse them:
- **repo**: an `owner/repo` or GitHub URL. Optional: by default, use the repo of the
  current directory.
- **`--milestone <title>`**: only issues in that milestone. Also accept a number, or
  a bare title that clearly names a milestone. Without it, take the whole open backlog.
- **`--parallel <n>`**: how many issues run at once. Default `1`, which means
  sequential. Never go above `5` unless the user insists: each session is a full
  `/implement-issue` run with its own subagents, and they share your rate limits.
- **`--rounds <n>`**: passed through to `/implement-issue` as its review rounds.
  Default: none, so each run picks its own.

You are the **orchestrator**. You never implement anything yourself. Each issue is
done by `/implement-issue` in its own background session (`claude --bg --worktree`):
a fresh context, its own worktree and branch, its own subagents. You choose what
runs next, start sessions, watch them, and keep the user informed. Your context has
to last for the whole backlog, so keep every step short. Scripts print one line per
issue or event. Never read session logs in full.

Scripts live in `${CLAUDE_SKILL_DIR}/scripts/`:

| Script | Does |
|---|---|
| `backlog.sh <repo> [milestone]` | Open issues in work order, one line each: `number  status  detail  title`. Status is `ready`, `blocked` (open blockers listed), `has-pr`, `assigned` (to someone else), `tracking` (epic or parent) or `skipped` (a label like `question` or `wontfix`). Blockers come from GitHub's native dependencies and from `Blocked by:` / `## Dependencies` text in the body. |
| `launch.sh <state> <repo> <issue> [rounds]` | Starts `/implement-issue` for the issue in background session `<repo>-<n>`, worktree `.claude/worktrees/issue-<n>`, and records it in `sessions.tsv`. Prints the session id. |
| `watch.sh <state> <repo> <milestone> <parallel>` | Waits silently, then prints events and exits: `finished`, `needs-input`, `ended`, `stalled`, `ready`. See the header of the script. |

## Phase 1: Set up

1. **Repo and checkout.** Run `gh repo view [<repo>] --json nameWithOwner,defaultBranchRef,hasIssuesEnabled`.
   The background sessions run in a local checkout of that repo, and the orchestrator
   runs from its main checkout (not from inside a worktree).
   - No repo given: use the current directory's repo. If it isn't a GitHub repo, stop
     and say so.
   - Repo given: if `git remote -v` here points to it, use this checkout. Otherwise
     **Ask** for the path of a local clone, or offer `gh repo clone <repo>`.
     Then `cd` into it.
2. **Milestone.** If one was given, check it exists (`gh api repos/<repo>/milestones?state=all`
   or `gh issue list --milestone`). If it doesn't, list the open milestones and **Ask**.
3. **State directory**, inside `.git` and never committed:
   `STATE="$(git rev-parse --path-format=absolute --git-common-dir)/work-backlog/<repo-slug>[-<milestone-slug>]"`.
   - `sessions.tsv`: one row per started issue (written by the scripts, read it but don't edit it).
   - `handled.txt`: issues never to start again in this run, one number per line.
   - `log.md`: one line per event and decision, written by you.
   If `STATE` already exists, this is a **resume**: compare `sessions.tsv` with
   `claude agents --json --all` and with what's on GitHub. Keep sessions that are
   still running. Treat issues that now have a PR as done. Tell the user what you
   picked up.
4. **Preflight.** `claude agents --json` works, `gh auth status` is fine, and the
   `implement-issue` skill exists (`~/.claude/skills/implement-issue` or the
   project's `.claude/skills/`). If it is missing, stop.
5. **Billing check.** Sessions should use the user's subscription, not API billing.
   - Run `claude auth status`. Expect `authMethod: claude.ai`, or a subscription
     `CLAUDE_CODE_OAUTH_TOKEN`.
   - If `ANTHROPIC_API_KEY` is set in the environment (`[ -n "${ANTHROPIC_API_KEY:-}" ]`),
     or an `apiKeyHelper` is configured, background sessions would bill that key
     instead. **Ask** before starting.
   - If `loginExpiresAt` falls within the next ~2 days, warn the user. Sessions stop
     making progress when the login expires.
   - Remind the user once that all sessions and their subagents share the plan's
     5-hour and weekly limits, and point them to `/usage`. Never pass `--bare`: it
     ignores the subscription login.

## Phase 2: Build the queue and start

1. Run `backlog.sh` and show the user the queue, compact:
   - the counts per status;
   - the `ready` issues in the order they will start, and how many run at once;
   - `blocked` issues with their blockers, so the waves are visible;
   - what is excluded and why (`has-pr`, `assigned`, `tracking`, `skipped`).
2. Watch for problems that would make the loop do the wrong thing, and **Ask** only
   if you find one: a dependency cycle (blocked issues with nothing ready that leads to
   them), or `ready` issues whose text says they are blocked in a way the script
   didn't catch. Otherwise don't wait for approval. Start right away.
3. Start the first `min(parallel, ready)` issues, in queue order, with `launch.sh`.
   For each one, log `started #n session <id>` and tell the user once:
   `claude attach <id>` to look in, `claude agents` to see them all.
   - If `launch.sh` exits 3 (the worktree from an earlier run is still there), look
     at it. Check `git -C .claude/worktrees/issue-<n> status` and whether its branch
     was pushed. If it holds work, don't touch it: add the issue to `handled.txt` and
     report it. If it is clean and pushed, `git worktree remove` it and launch again.
4. Start the watcher in the background:
   `${CLAUDE_SKILL_DIR}/scripts/watch.sh "$STATE" <repo> "<milestone or empty>" <parallel>`
   (Bash with `run_in_background`). It exits on the first event, so you get exactly
   one notification per batch of events. Don't poll it and don't sleep.

## Phase 3: The loop

On each watcher notification, handle every event line, then start the watcher again.
Run exactly one watcher at a time.

| Event | What to do |
|---|---|
| `finished <n> <id> status: pr-open <url> ...` | Log it. Check the PR exists (`gh pr view <url> --json state,headRefName`). Then `claude rm <id>`: it removes the worktree, and the branch is pushed. Tell the user in one line: `#n → <url> (ci=…)`. |
| `finished <n> <id> status: stopped|failed <reason>` | Log it, add `<n>` to `handled.txt`, keep the worktree, and tell the user the reason and `claude attach <id>`. Don't retry on your own. |
| `needs-input <n> <id>` | The session asked a question or hit a permission prompt. Tell the user: `#n needs you: claude attach <id>`, and send a `PushNotification` when the user may be away. Keep the slot counted as busy and carry on with the others. |
| `ended <n> <id> <state>` | It crashed or was stopped with no result. Log it, add `<n>` to `handled.txt`, keep the worktree, and report it. |
| `stalled <n> <id>` | Idle for a long time with no result. Look at the tail of `claude logs <id>` (`| tail -40`) and at `<git-common-dir>/implement-issue/<n>/log.md`. If it is waiting for CI, leave it alone. Otherwise tell the user to attach. |
| `ready <n> ...` | A slot is free and these issues can start: `launch.sh` each one, in the order given. |

After handling the events, decide whether to keep going:
- **Keep looping** while any session is active, or any issue is `ready`, or any
  `blocked` issue waits only on issues that have an open PR from this run. The user
  merging those PRs is what unblocks the next wave. The watcher re-checks the backlog
  every 5 minutes, so newly unblocked issues show up as `ready` on their own.
- When the only thing left is waiting for merges, say so once, with the PRs to
  merge and what each one unblocks. Don't repeat it on every event.
- **Stop** when no session is active, nothing is `ready`, and nothing blocked can
  ever unblock from this run (its blockers failed, are excluded, or are outside the
  queue and not moving). Then go to Finish.

Rules:
- **Never** merge a PR, close or edit an issue, or push. The sessions open the PRs.
  The user merges.
- Never start an issue that `backlog.sh` doesn't report as `ready`, and never start
  one twice in a run. `sessions.tsv` and `handled.txt` are the record.
- Parallel sessions can touch the same files. If two `ready` issues clearly overlap
  (same module, both refactor the same thing), start them one after the other even
  when `parallel` allows more, and say why.
- If the user tells you something mid-run ("skip #12", "stop after this wave",
  "parallel 3"), apply it: `handled.txt` for skips, the watcher's `parallel` argument
  for the slot count (restart the watcher).
- Keep messages to the user to one line per event. The full story is in `log.md`
  and in each issue's `result.md`.

## Finish

When the loop stops, or the user stops it, report:
- a table of the issues: `#n | title | PR or reason | CI`;
- what still waits and on which merges;
- which issues failed or stopped, each with `claude attach <id>` and where its notes are;
- worktrees left behind on purpose (`git worktree list`).

If the user stops the run, don't stop the sessions that are still working unless
they ask (`claude stop <id>`). Running `/work-backlog` again with the same arguments
resumes from `STATE`.

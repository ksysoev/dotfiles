---
name: implement-issue
description: Take a GitHub issue from requirements to a green pull request. Analyzes the issue, plans, implements on a feature branch, runs review-and-fix rounds, checks the feature by hand, opens a PR and fixes CI until it passes. Use when the user gives a GitHub issue URL or number and asks to implement, build or ship it.
argument-hint: <issue-url-or-number> [review-rounds]
arguments: [issue, rounds]
disable-model-invocation: true
allowed-tools: Bash(gh issue view *) Bash(gh pr view *) Bash(gh pr checks *) Bash(gh run view *) Bash(gh run list *) Bash(git status *) Bash(git diff *) Bash(git log *) Bash(git fetch *) Bash(git rev-parse *)
---

# Implement a GitHub issue end to end

Issue: `$issue`. Review rounds: `$rounds` (if it is empty, pick it yourself from
the size of the change; see "Choosing the number of review rounds").

You own this issue until there is an open, green pull request for it. Work through
the phases in order and keep a todo list with one item per phase. Don't stop
between phases to ask permission. Stop only at the checkpoints marked **Ask**, or
when you are blocked.

## Ground rules

- **The repo's instructions come first.** This skill says *what* to do. The project
  says *how*: build, test, lint, format, commit style, branch naming and how to run
  the app. That lives in `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, `.github/`
  (PR template, CI workflows), task runner files (`Makefile`, `justfile`,
  `package.json` scripts...) and recent commits. Where the repo says nothing, copy
  what the existing code and git history already do.
- **The issue defines the scope.** Anything the issue doesn't ask for is out of scope:
  refactors, renames, unrelated fixes. Write it down as a follow-up instead.
- **Evidence over assertion.** Never say something works without running the check
  that proves it. Report failures with their output.
- **Never** merge the PR, force-push to the default branch, skip hooks (`--no-verify`)
  or disable, delete or weaken a test or check to get green. If a check looks wrong,
  say why and **Ask**.
- **Don't destroy local work.** If the working tree has changes you didn't make,
  **Ask** before you stash, reset or switch branches.

## Context strategy: coordinate, delegate the noisy work

This workflow is long. Keep the main context for what only it can do: talking
to the user, decisions about scope and design, and the gates between phases.
Hand self-contained, noisy steps to subagents, and take back only short
reports. The brief for each subagent is in [subagent-briefs.md](subagent-briefs.md).
Read that file the first time you delegate. This skill's files are in
`${CLAUDE_SKILL_DIR}`; use that path wherever a brief says `<skill dir>`.

| Step | Where it runs | Why |
|---|---|---|
| Talking to the user, scope and design decisions, triage verdicts | main | needs the user and the whole picture |
| Code exploration | read-only subagent (e.g. `Explore`) | many file reads, small summary |
| Implementation and fixes | implementer subagent | edits plus check output; result is a diff |
| Review | `code-review` skill or reviewer subagent | a fresh context is the point |
| Checking review findings | read-only subagent | reading code to confirm or refute claims |
| Manual verification | tester subagent | tmux captures and app logs are very verbose |
| CI failure diagnosis | subagent | CI logs are long |
| git, `gh pr create`, quick status checks | main | small output, needs the decisions |

Rules for delegating:
- **Pass notes through files, not through long prompts.** Keep the shared state in a
  notes directory outside the work tree:
  `NOTES="$(git rev-parse --git-common-dir)/implement-issue/<issue-number>"`. It is
  inside `.git`, so it is never committed. Hand subagents the paths, not the content.
  - `brief.md`: issue link, goal, acceptance criteria, out of scope, assumptions, and
    the repo's exact build/test/lint/run commands.
  - `plan.md`: the implementation plan.
  - `log.md`: what each phase did, one short entry per phase or review round:
    findings and verdicts, manual checks and what you saw, CI fixes.
- **One writer at a time.** Only one subagent edits the working tree at a time.
  Read-only subagents may run in parallel.
- **Bounded reports.** Every brief asks for a short structured report (under ~40 lines):
  what changed, the commands run and their exit codes, problems. No raw logs or full diffs.
- **Check, don't trust.** After a subagent that edits code, look at `git status` and
  `git diff --stat` yourself, and run the project's checks with output cut to the
  result (e.g. `<check> >/dev/null 2>&1; echo "exit=$?"`, or `| tail -20` when it
  fails). A summary is not evidence; an exit code is.
- **Don't delegate what is cheap.** A one-line fix or a single command is faster done
  directly than briefed.

## Phase 1: Start from a fresh default branch

1. `git status`. If the tree is dirty, **Ask** (see ground rules).
2. Find the default branch (`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`),
   check it out and fast-forward it from the remote (`git pull --ff-only`).
3. If the issue lives in a different repo than the current directory, **Ask**.
4. Create the notes directory (`mkdir -p "$NOTES"`).

## Phase 2: Understand the requirements

1. Read the whole issue, comments included, in the main context:
   `gh issue view <issue> --comments`. It is the source of truth and usually short.
   Open linked issues or PRs only when the issue depends on them.
2. Start a read-only exploration subagent (brief: *Explorer*). It finds the code
   the change touches, the closest existing feature to copy, its tests and docs,
   and the repo's commands for checking and running the project.
3. Write `brief.md`: goal (one or two sentences), acceptance criteria (concrete and
   checkable; mark the ones you inferred), out of scope, assumptions, open questions,
   and the check/run commands.
4. **Ask** only when an open question would change the design or the user-facing
   behavior and neither the issue nor the code answers it. Ask everything in one go,
   each question with your recommended answer. For small ambiguities, pick the
   conventional option, record it as an assumption and keep going.

## Phase 3: Plan

Write `plan.md`: the files to change, the approach, how each acceptance criterion
will be proven (which tests, which manual check) and the risks. Make it concrete
enough that an implementer starting from zero can follow it without guessing.
Prefer the smallest change that meets the criteria and fits the existing design.
If the issue is too big for one reviewable PR, propose a split and **Ask**.

End the plan with the size of the change and the review rounds it gets (see below).

Show the plan to the user, then continue unless they stop you.

### Choosing the number of review rounds

If the user passed `rounds`, use it and skip this. Otherwise pick the budget from
how big and risky the change is:

| Size | Typical change | Max rounds |
|---|---|---|
| Small | Small bug fix or small feature: one area, a few files, roughly under ~150 changed lines, no new design | 1 |
| Medium | A feature or fix across several files or modules, or with a new design decision | 2 |
| Large | A big feature with a lot of code (roughly 500+ changed lines or many modules), or any change to risky code: concurrency, security, auth, persistence, migrations, public APIs | 3 |

- Never go above 3 unless the user asks.
- When in doubt between two sizes, pick the larger one. Rounds stop early anyway
  when they find nothing.
- Write the size, the budget and a one-line reason in `plan.md`.
- After Phase 4, check the real size with `git diff --stat <default-branch>...HEAD`.
  If it turned out clearly bigger or smaller than planned, change the budget and
  note why in `log.md`.

## Phase 4: Implement

1. Create a feature branch from the updated default branch, in the main context. Use
   the repo's naming convention; if there is none, use `<type>/<issue-number>-<slug>`,
   e.g. `feat/61-split-view`.
2. Start an implementer subagent (brief: *Implementer*) with `brief.md` and `plan.md`.
   It writes the code and tests, updates docs if the behavior changed, and runs
   the checks until they pass. It does not commit.
3. Check its work (see "Check, don't trust"). If it reported a deviation from the
   plan, decide whether it's acceptable. If the work is incomplete, start it again
   with the specific gap.
4. Commit in logical units with messages in the repo's style, mentioning the issue
   where the repo does that. Push (`git push -u origin <branch>`). Append to `log.md`.

## Phase 5: Review rounds

Repeat up to the round budget: `rounds` if the user gave it, otherwise the budget
from `plan.md` (see "Choosing the number of review rounds"). Stop early when a round
finds nothing that is both valid and in scope. If the last allowed round still finds
valid in-scope problems, fix them, but don't start another round on your own. Say in
the final report that the budget ran out.

1. **Review.** If a `code-review` skill or command is available, run it on the
   current changes. Otherwise start a reviewer subagent (brief: *Reviewer*).
2. **Check the findings.** Start a read-only subagent (brief: *Finding checker*)
   with the findings and `brief.md`. It opens the code, tests each claim, and
   suggests one of:
   - **Valid, in scope**: a real problem in code this branch adds or changes, or one
     that blocks an acceptance criterion. Fix it.
   - **Valid, out of scope**: real, but it was there before or the issue doesn't ask
     for it. Add it to the follow-ups.
   - **Invalid**: wrong, already handled or speculative, with a one-line reason.
   If there are only one or two findings, check them yourself instead.
3. **Decide** in the main context. The checker suggests; you decide, using the scope
   in `brief.md`. Look at the code yourself only where a verdict seems doubtful.
   Record each finding and its verdict in `log.md`.
4. **Fix** the valid in-scope findings: write the fix list into `log.md` and start
   the implementer with it (brief: *Implementer*, fix mode). Ask for a regression
   test where it makes sense.
5. **Check, commit and push** the fixes, with messages that say what was fixed.

## Phase 6: Manual verification

Tests prove the code; now prove the feature. Start a tester subagent
(brief: *Manual tester*) with `brief.md`. It runs the real app the way a user would,
walks through every acceptance criterion and the important edge cases, and reports
pass or fail for each criterion with short evidence. If the project documents how
to run it (a `run` or `verify` skill, CLAUDE.md, README), the tester does that. If
not, [manual-testing.md](manual-testing.md) explains how to drive CLIs, TUIs,
editors and servers, including with tmux.

The tester reports and does not fix. For each failure: send it to the implementer,
check, commit, push, and test again. Record the results in `log.md`.

If the feature can't be run here (it needs credentials, hardware or a deployed
service), say so plainly and describe what a human should check.

## Phase 7: Open the pull request

1. Make sure the branch is pushed and up to date with the default branch. If the
   default branch has moved and it conflicts, rebase or merge as the repo prefers,
   then check again.
2. Open the PR with `gh pr create`, written from `brief.md`, `plan.md` and `log.md`.
   Fill the repo's PR template if there is one. Otherwise include:
   - **Summary**: what changed and why, in a few sentences.
   - `Closes #<issue>` (or the repo's linking convention).
   - **Implementation notes**: the approach and the assumptions you made.
   - **Testing**: the automated checks and manual steps, with what you saw.
   - **Review**: a short summary of the review rounds (how many ran out of the budget, and why that budget).
   - **Follow-ups**: valid out-of-scope findings, if any.
   Use a draft PR only if the repo or the user asks for one.

## Phase 8: Get CI green

1. Wait for the checks: `gh pr checks --watch` in the background, so its output
   stays out of the context until it finishes.
2. For each failed run, start a CI-fixer subagent (brief: *CI fixer*) with the run ID
   and `brief.md`. It reads the failed logs, finds the root cause, reproduces it
   locally if it can, and either fixes it (if the cause is in this branch) or reports
   it as unrelated, with evidence.
3. Check its fix, commit, push and wait again. For a failure that has nothing to do
   with this change, make sure the evidence is convincing. For a suspected flake,
   re-run once (`gh run rerun <run-id> --failed`); don't "fix" it in this PR.
4. After three fix attempts for the same failure, stop and **Ask**.

## Finish

Report to the user briefly:
- The PR link and its CI status.
- How each acceptance criterion is met and proven.
- The review budget chosen and why, then what the rounds found, fixed and rejected.
- What manual verification showed.
- Assumptions, follow-ups and anything you couldn't verify.

The notes directory can stay. It is local, inside `.git`, and useful if the PR
needs more work later.

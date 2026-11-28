---
name: plan-feature
description: Turn feature requirements into one or more GitHub issues ready to implement. Explores the codebase, grills the user in rounds until every decision is settled, slices the work into vertical, independently shippable issues with blocking edges, and publishes them after the user approves. Use when the user gives feature requirements (text, a file or an issue) and asks to plan, spec, break down or file issues for it.
argument-hint: <requirements text | path to file | issue url-or-number>
disable-model-invocation: true
allowed-tools: Bash(gh issue view *) Bash(gh issue list *) Bash(gh label list *) Bash(gh repo view *) Bash(git status *) Bash(git log *) Bash(git remote *) Bash(git rev-parse *)
---

# Plan a feature into GitHub issues

Requirements: `$ARGUMENTS`

If that is a file path, read the file. If it is an issue URL or number, read it with
`gh issue view <issue> --comments`. If it is empty, ask the user for the requirements
and stop until they answer.

Your output is GitHub issues that someone (a person, or `/implement-issue`) can pick
up cold and finish without coming back to ask. Your job here is to plan, not to build:
write no code and change no files in the work tree.

Work through the phases in order. Stop only at the **Ask** checkpoints.

## Ground rules

- **Facts are your job, decisions are the user's.** Never ask the user something the
  code, git history, docs or existing issues can answer. Look it up. Never settle a
  decision for the user by assuming it. Put it to them, with your recommendation.
- **The repo's conventions come first.** Issue templates in `.github/ISSUE_TEMPLATE/`,
  existing labels, issue types and how past issues are written beat the defaults here.
- **Nothing is published without approval.** The user sees every title and body
  before anything is created.
- **No silent assumptions.** Each assumption is either confirmed by the user or
  written into the issue under *Assumptions*, where the implementer will see it.
- **Use the project's words.** Name things the way the code and docs already do.

Keep working notes in
`NOTES="$(git rev-parse --git-common-dir)/plan-feature/<feature-slug>"` (inside `.git`,
never committed): `decisions.md` for the settled decisions, then `issues/NN-<slug>.md`
for the drafts. They survive context compaction and let you publish with
`--body-file`.

## Phase 1: Understand the requirements and the code

1. Confirm the target repo: `gh repo view --json nameWithOwner,hasIssuesEnabled`. If it
   is a fork or not the user's repo, or issues are disabled, **Ask** where to file.
2. Restate the requirements to yourself: the problem, who has it, the goal, and
   what *done* looks like from the user's side.
3. Start a read-only exploration subagent (e.g. `Explore`) with a fresh context. Ask it
   for a report under ~40 lines covering:
   - the modules and seams the feature touches, and the closest existing feature to copy
   - constraints the code imposes (data model, public APIs, config, compatibility)
   - how features are tested here, and where the docs live
   - anything in the code that contradicts or already covers part of the requirements
4. At the same time, look for overlap yourself:
   `gh issue list --state all --search "<key terms>" --limit 20`. Note duplicates and
   related issues to link.
5. Write what you learned into `decisions.md` (facts section).

Skip the subagent when the feature is clearly tiny and the relevant code is a file
or two; read it yourself.

## Phase 2: Grill the user until nothing is open

Map the open questions as a **decision tree**: each decision opens the ones that hang
off it. The **frontier** is every open decision whose prerequisites are already
settled. Ask the whole frontier in one round, wait for the answers, recompute the
frontier, ask the next round. A question that depends on another question in the
same round belongs to a later round.

Find the gaps with this checklist. Use it as a scan; don't ask the user about every
item. Ask only about the ones that are unclear **and** would change behavior, scope or
design:

- scope: what is in, what is explicitly out, which users or roles
- behavior: the main flows, plus the error, empty, edge and concurrent cases
- data: new or changed entities, migrations, compatibility with existing data
- interfaces: CLI flags, API contracts, config keys, UI, and their defaults
- non-functional: performance, security, privacy, observability, only where it matters
- rollout: feature flags, backwards compatibility, deprecations, docs
- done: what observable result proves each part works

Format each round like this, numbering across rounds:

```
❓ **Q1** - **<short title>**: <the question, with the options if there are any,
and the trade-off in a sentence or two>

➡️ <your recommended answer and why, in one line>

---

❓ **Q2** - ...
```

- Word each question so that "yes" accepts your recommendation. The user can answer
  `yes` to everything, or answer by number.
- Lead each question with the context the user needs. They may not have the code in
  their head.
- If a fact is needed mid-round, start a subagent to look it up. Ask the questions
  that don't depend on it now; ask the rest once it reports.
- Record every answer in `decisions.md` as you go.
- If the user says "you decide" or "skip", take your recommendation and record it
  as an assumption.

Stop grilling when the frontier is empty. A two-line, obvious feature may need no
questions at all. Say so and move on.

**Ask** for confirmation of the shared understanding: a short summary of the
goal, the decisions and what is out of scope. Don't move to Phase 3 until the user
agrees.

## Phase 3: Decide the shape: one issue or several

**One issue** when the whole feature fits one reviewable pull request and one
working session, and one set of acceptance criteria covers it.

**Several issues** otherwise. Slice the work vertically, as **tracer bullets**:

- Each issue cuts a narrow but complete path through every layer it needs (data,
  logic, interface, tests, docs), so that once merged it is demoable or verifiable
  on its own. Don't split by layer ("DB issue", "API issue", "UI issue"): none of
  those can be checked alone.
- Each issue fits one pull request and one fresh agent session.
- Put a refactor that makes the feature easy first, as its own issue ("make the
  change easy, then make the easy change").
- A wide mechanical change (renaming a shared type or a column used everywhere)
  can't land as one slice. Sequence it as expand, migrate in batches, contract.
- Leave out what wasn't decided. A follow-up that isn't needed now goes in the
  *Out of scope* list, not into an issue.

When there are several issues, add a **parent issue** that holds the goal, the
decisions and the list of children. The children are its sub-issues.

### Dependencies

With several issues, write down the dependency graph explicitly. Every issue gets
a **blocked by** list: the issues that must be merged before work on it can start.
"None" is an answer too, and it means the issue can start right away.

- An edge means "can't start, or can't be merged, without it": it needs code, a
  schema, an interface or a decision that the other issue delivers. Ordering by
  taste, or "it would be nicer first", is not an edge.
- Too few edges and someone starts an issue that can't be finished. Too many and
  work that could run in parallel waits. Check each edge both ways.
- No cycles. If two issues need each other, the split is wrong: merge them or
  pull the shared part into its own issue that blocks both.
- These edges are published as GitHub's native issue dependencies (the
  *Relationships* field: blocked by / blocking), not just as text in the body.

### Milestones for phases

When the feature needs a significant number of issues (as a rule of thumb, more
than about six), or it falls naturally into stages, group the issues into
**milestones**, one per phase of development:

- Each phase ends in something usable or demoable: a working core first, then the
  extensions, then the polish. A phase is not a layer ("backend", "frontend").
- Phases are ordered. An issue may be blocked by issues in its own phase or
  earlier phases, never later ones. If it is, move one of them.
- Name each milestone `<Feature>: <phase>`, for example `Export: 1 - CSV core`,
  with a one-line description of what the phase delivers.
- Reuse a matching milestone that already exists
  (`gh api repos/{owner}/{repo}/milestones --jq '.[].title'`) instead of making a
  duplicate. Set due dates only if the user gives them.

For fewer issues, don't use milestones; the parent issue and the dependencies are
enough.

If the work is far too large to plan in one session, with major decisions that
need research or prototypes first, say so, and propose planning only the first,
clear part now.

## Phase 4: Draft and review with the user

Draft every issue into `$NOTES/issues/`, numbered in dependency order (blockers
first). Use the repo's issue template if there is one. Otherwise use the templates
in [issue-templates.md](issue-templates.md) (in `${CLAUDE_SKILL_DIR}`).

Before showing the drafts, check them yourself:

- Every decision from `decisions.md` is in some issue, or is listed as out of scope.
- Every acceptance criterion is observable and checkable, not "works well" or "is fast".
- Each issue makes sense to someone who reads only that issue and its parent.
- No two issues overlap, and together they cover the whole feature.
- No exact file paths, line numbers or code. They go stale. Name modules and
  behavior instead. Exception: a type, schema or interface shape the user decided on.

- The dependency graph has no cycles, and no issue depends on a later milestone.

**Ask** for approval. Show the breakdown first, grouped by milestone if there are
any, then the full bodies:

```
Milestone "Export: 1 - CSV core": export one table to CSV from the CLI
  1. <title>  (blocked by: none)       <one line on what it delivers>
  2. <title>  (blocked by: 1)          ...
Milestone "Export: 2 - Formats": ...
  3. <title>  (blocked by: 2)          ...

Can start now: 1
```

Ask whether the granularity is right, whether the blocking edges are right, whether
the phases are right (if any), and whether anything should be merged, split,
dropped or worded differently. Iterate
until the user approves. Also confirm the labels: use labels that already exist
(`gh label list`); create a new one only if the user wants it.

## Phase 5: Publish

Create the issues with `gh`, in dependency order, so every blocker exists before
the issues it blocks:

1. If phases were agreed, create the missing milestones first:
   `gh api repos/{owner}/{repo}/milestones -f title="<title>" -f description="<what the phase delivers>"`.
2. With several issues, create the parent next. Put it in the first milestone.
3. Create each child: `gh issue create --title ... --body-file <draft> --parent <parent>
   --blocked-by <n,n> --milestone "<title>"` plus `--label` / `--type` as agreed.
   Use the real numbers returned by earlier creates. Never write a placeholder like
   `#<n>`; GitHub links it to an unrelated issue.
4. **Check the dependencies landed.** For every issue with blockers, compare
   `gh issue view <n> --json blockedBy --jq '[.blockedBy.nodes[].number]'` with the
   approved graph. Add a missing edge with `gh issue edit <n> --add-blocked-by <m>`
   and remove a wrong one with `--remove-blocked-by`.
5. If `gh` can't set dependencies (old `gh`), use the REST API:
   `gh api --method POST repos/{owner}/{repo}/issues/<n>/dependencies/blocked_by -F issue_id=<blocker database id>`,
   where the database id is `gh api repos/{owner}/{repo}/issues/<m> --jq .id`, not
   the issue number. Only if the repo has no dependencies at all (some GitHub
   Enterprise versions) fall back to a `Blocked by: #<n>` line at the top of the
   body, and tell the user. Do the same with `Part of #<parent>` if sub-issues
   aren't available.
6. Update the parent's body with the real child numbers, grouped by milestone
   (`gh issue edit <parent> --body-file ...`).
7. If the requirements came from an existing issue, link the new issues to it
   (sub-issues, or a comment listing them). Don't close it or rewrite its body
   unless the user asks.

If a create fails partway, stop, report what was created, and fix forward. Never
create duplicates by retrying blindly; check with `gh issue list` first.

## Finish

Report briefly:

- Each issue as `#<n> <title>` with its link, grouped by milestone if there are
  any, in dependency order, marked with what blocks it, and which ones can start
  now.
- Whether every dependency was set as a native GitHub dependency, or which ones
  fell back to text.
- The assumptions recorded in the issues.
- What was ruled out of scope.
- The next step: `/implement-issue <n>` on an issue that nothing blocks.

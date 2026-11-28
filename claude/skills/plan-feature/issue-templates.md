# Issue templates

Use these only when the repo has no issue template of its own. Drop a section that
would be empty, except *Acceptance criteria*, which every issue needs.

Write for a reader who has not seen the conversation: an engineer or an agent
starting cold. Describe behavior from the user's side. Say what, not how; the
implementer reads the code and picks the how, unless the user settled it.

## Single issue (the whole feature fits one PR)

```markdown
## Problem

Who has the problem and why it matters, in two or three sentences.

## Solution

What changes for the user once this is done. The main flow, then the edge and
error cases that were decided.

## Acceptance criteria

- [ ] <an observable, checkable result: a command and its output, a response, a UI state>
- [ ] <the error and edge cases that were decided>
- [ ] Tests cover <the behavior>, next to the existing tests for <the closest feature>
- [ ] Docs updated: <where>, if user-facing behavior changes

## Decisions

- <decision>: <the choice made and, in a few words, why>

## Assumptions

- <what was assumed and not confirmed, so the implementer can question it>

## Out of scope

- <what this deliberately doesn't do, so nobody adds it>

## Context

Related issues, the closest existing feature to copy, and any constraint found in
the code. Name modules, not file paths.
```

## Parent issue (several issues)

```markdown
## Goal

The problem and the desired result, in a few sentences.

## Decisions

- <decision>: <choice>, <why>

## Plan

Dependencies are set as GitHub issue dependencies; the list below is for reading.

### <Milestone 1 title>: <what the phase delivers>

1. #<n> <title>: <what it delivers>
2. #<n> <title> (blocked by #<n>): <what it delivers>

### <Milestone 2 title>: ...

(Without milestones, one flat list.)

## Out of scope

- <ruled out, and why>
```

## Child issue (one slice)

```markdown
Part of #<parent>.

## What to build

The end-to-end behavior this slice makes work, from the user's side. Not a list of
layers.

## Acceptance criteria

- [ ] <observable, checkable result>
- [ ] Tests cover <the behavior>

## Notes

Decisions, assumptions and constraints that apply to this slice only. The shared
ones live in the parent.
```

Leave out the `Part of` line when the issue was created with `--parent`. Don't
list dependencies in the body: they live in GitHub's dependency field, so they
can't drift out of date. Add a `Blocked by: #<n>` line only when native
dependencies were not available.

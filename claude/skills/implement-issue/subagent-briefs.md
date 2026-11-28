# Subagent briefs

Templates for the subagents in SKILL.md. Each subagent starts with no context:
it knows only what the brief and the files it names tell it. Fill in the
`<placeholders>`, pass file paths rather than pasting content, and keep each
brief's output contract so the reports stay short.

Shared lines to include in every brief:

> Repo: `<repo root>`. Notes: `<NOTES>`. Read `<NOTES>/brief.md` first: it has the
> goal, acceptance criteria, scope and the project's commands. Follow the repo's own
> instructions (CLAUDE.md, AGENTS.md, CONTRIBUTING.md) over general habits. Don't
> commit, push, or touch git history. Don't change anything outside the repo.
> Final report: under ~40 lines, in the format below. No raw logs or full diffs:
> quote at most a few lines of key output.

## Explorer (read-only)

> Task: get ready to implement <issue link>: <one-line goal>. Find:
> 1. the files and functions the change will most likely touch, as `path:line`, each
>    with one line on its role;
> 2. the closest existing feature or pattern to copy, and where its tests are;
> 3. the project's commands to build, test, lint/format and run the app, with
>    where you found each one (file and line);
> 4. conventions that apply: test style, error handling, docs/changelog, branch and
>    commit style from `git log`;
> 5. risks or surprises: tight coupling, missing tests, generated code.
> Report as those five numbered sections.

(There is no `brief.md` yet at this stage. Pass the issue's text or link instead.)

## Implementer (writes code)

> Task: implement `<NOTES>/plan.md` for the criteria in `<NOTES>/brief.md`.
> — or, fix mode: fix the findings listed under "<round heading>" in `<NOTES>/log.md`.
> - Follow the plan. If it is wrong or incomplete, make the smallest sensible
>   change and report it as a deviation. Don't redesign.
> - Stay in scope: no unrelated refactors, renames or formatting churn.
> - For each acceptance criterion or fixed finding, add or extend a test that fails
>   without the change, where the project has tests for that kind of code.
> - Update docs, changelog and help text if the repo keeps them and the behavior changed.
> - Run the project's checks from brief.md until they pass. Fix the causes; never
>   skip, weaken or delete checks.
> Report: files changed (one line each); tests added; each check command with its
> exit code; deviations from the plan; anything unfinished or uncertain.

## Reviewer (read-only; used when no `code-review` skill is available)

> Task: review the changes on this branch: `git diff <default-branch>...HEAD`.
> Check them against the acceptance criteria in brief.md and the repo's instructions.
> Look for correctness bugs, missing edge cases, unmet criteria, broken error
> handling, missing tests for new behavior, and violations of repo conventions. Skip
> pure style issues that linters already catch. Don't fix anything.
> Report: a numbered list of findings, most severe first, each with `path:line`, the
> problem, a concrete failure scenario, and a severity (high/medium/low). Say
> "no findings" if there are none.

## Finding checker (read-only)

> Task: check each review finding below against the actual code. Findings:
> <numbered list, or a path in log.md>.
> For each one, open the code and decide whether the claim is true. Test it if that
> is cheap (a quick run or a scratch test outside the repo, then delete it). Compare
> with `git diff <default-branch>...HEAD` to see whether this branch introduced it.
> Suggest a verdict:
> - VALID-IN-SCOPE: real, and introduced or touched by this branch, or blocks a criterion;
> - VALID-OUT-OF-SCOPE: real, but it was there before or the issue doesn't ask for it;
> - INVALID: wrong, already handled or speculative.
> Report: one line per finding: `<n>. <VERDICT> — <evidence in one sentence>`, then
> for each VALID-IN-SCOPE finding a one-line suggested fix.

## Manual tester (runs the app; doesn't edit the repo)

> Task: check the feature by hand, the way a user would, against every acceptance
> criterion in brief.md, plus the obvious edge cases and error paths.
> Build and run the app from the working tree using the repo's documented way. If
> there is none, follow `<skill dir>/manual-testing.md`. Use throwaway config, data
> and home directories, so the user's real setup isn't used or changed. Clean up
> sessions, processes and temp files when you are done. Don't fix code. Report
> problems.
> Report: one line per criterion: `PASS|FAIL|BLOCKED — <what you did> → <what you saw>`;
> for each FAIL, the exact steps to reproduce and a few lines of captured output; then
> any other problems you noticed.

## CI fixer (writes code)

> Task: CI run `<run-id>` failed on PR `<pr>`. Read the failure with
> `gh run view <run-id> --log-failed` (filter it; don't dump it all) and find the
> root cause.
> - If the cause is in this branch's changes, reproduce it locally if you can, fix
>   it, and run the relevant checks until they pass.
> - If it isn't (a flaky test, infrastructure, already failing on the default
>   branch: check recent runs there with `gh run list`), don't change code.
>   Collect the evidence.
> Never skip, weaken or delete checks.
> Report: failing job and step; root cause in two or three sentences, with the key
> log lines; RELATED or UNRELATED; files changed and the local check exit codes, if
> you fixed it.

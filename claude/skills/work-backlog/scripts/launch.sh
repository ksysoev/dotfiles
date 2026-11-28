#!/usr/bin/env bash
# launch.sh <state-dir> <owner/repo> <issue-number> [review-rounds]
#
# Starts `/implement-issue` for one issue in a new background Claude Code
# session, in its own git worktree (.claude/worktrees/issue-<n>), and records
# it in <state-dir>/sessions.tsv. Run it from the repo's main checkout.
# Prints the session id.
set -euo pipefail

state="${1:?usage: launch.sh <state-dir> <owner/repo> <issue> [rounds]}"
repo="${2:?missing repo}"
issue="${3:?missing issue number}"
rounds="${4:-}"

top="$(git rev-parse --show-toplevel)"
cd "$top"

if [ -e ".claude/worktrees/issue-${issue}" ]; then
  echo "worktree .claude/worktrees/issue-${issue} already exists (left from an earlier run?)" >&2
  exit 3
fi

prompt="/implement-issue https://github.com/${repo}/issues/${issue}"
[ -n "$rounds" ] && prompt="${prompt} ${rounds}"

out="$(claude --bg --worktree "issue-${issue}" --name "${repo##*/}-${issue}" "$prompt" 2>&1)" || {
  echo "$out" >&2
  exit 1
}
id="$(printf '%s\n' "$out" | awk -F' · ' '/backgrounded/ {print $2; exit}')"
if [ -z "$id" ]; then
  echo "could not read the session id from: $out" >&2
  exit 1
fi

mkdir -p "$state"
# issue  session  reported-state  done-since(epoch)
printf '%s\t%s\t%s\t%s\n' "$issue" "$id" "started" "-" >>"$state/sessions.tsv"
echo "$id"

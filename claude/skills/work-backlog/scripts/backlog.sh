#!/usr/bin/env bash
# backlog.sh <owner/repo> [milestone-title]
#
# Prints the open issues of a repo (optionally one milestone), one per line,
# tab-separated, in the order they should be worked:
#
#   <number>  <status>  <detail>  <title>
#
# status is one of:
#   ready     can start now
#   blocked   waiting on open issues (detail: #n,#m)
#   has-pr    an open PR already closes it (detail: PR numbers)
#   assigned  assigned to someone else (detail: logins)
#   tracking  has open sub-issues, or is a tracking/epic/roadmap issue: the
#             issues under it are the work
#   skipped   carries a label that means "not work" (detail: label)
#
# Blockers come from GitHub's native issue dependencies and, for repos that
# write them as text, from "Blocked by: #n" / "Depends on: #n" lines and from
# a "## Dependencies" / "## Blocked by" section in the body. A text blocker
# counts while it is still an open issue in the same repo.
#
# Order: milestone due date (no due date, then no milestone, last), then issue number.
set -euo pipefail

repo="${1:?usage: backlog.sh <owner/repo> [milestone-title]}"
milestone="${2:-}"

me="$(gh api user --jq .login)"
open_numbers="$(gh issue list -R "$repo" --state open --limit 2000 --json number --jq '[.[].number]')"
q="repo:${repo} is:issue is:open"
[ -n "$milestone" ] && q="${q} milestone:\"${milestone}\""

# shellcheck disable=SC2016
gh api graphql --paginate -f q="$q" -f query='
query($q: String!, $endCursor: String) {
  search(query: $q, type: ISSUE, first: 100, after: $endCursor) {
    pageInfo { hasNextPage endCursor }
    nodes {
      ... on Issue {
        number title body
        milestone { title dueOn }
        assignees(first: 10) { nodes { login } }
        labels(first: 20) { nodes { name } }
        subIssuesSummary { total completed }
        blockedBy(first: 50) { nodes { number state repository { nameWithOwner } } }
        closedByPullRequestsReferences(first: 10, includeClosedPrs: false) { nodes { number state } }
      }
    }
  }
}' --jq '.data.search.nodes[]' |
  jq -rs --arg me "$me" --arg repo "$repo" --argjson open "$open_numbers" '
    def skiplabel: map(select(test("^(duplicate|invalid|wontfix|won.t fix|question|discussion)$"; "i"))) | first;
    # Issue numbers named as blockers in the body text.
    def textblockers:
      (. // "") | gsub("\r"; "") | split("\n") as $lines
      | reduce $lines[] as $l ({sec: false, seen: false, out: []};
          if ($l | test("^#{1,6} "))
          then .sec = ($l | test("^#{1,6} +(dependencies|blocked by|depends on)\\b"; "i")) | .seen = false
          elif .sec and ($l | test("^\\s*$")) then (if .seen then .sec = false else . end)
          elif .sec then .seen = true
          else . end
          | if .sec or ($l | test("^[-*> ]*(\\*\\*)?(blocked by|depends on)(\\*\\*)?:?"; "i"))
            then .out += [$l | scan("(?<![\\w/])#([0-9]+)") | .[0] | tonumber]
            else . end)
      | .out | unique;
    map(
      . as $i
      | (([.blockedBy.nodes[] | select(.state == "OPEN")
          | if .repository.nameWithOwner == $repo then "#\(.number)" else "\(.repository.nameWithOwner)#\(.number)" end])
         + [.body | textblockers | .[] | select(. as $n | $open | index($n)) | select(. != $i.number) | "#\(.)"]
        | unique) as $blockers
      | ([.closedByPullRequestsReferences.nodes[] | select(.state == "OPEN") | "#\(.number)"]) as $prs
      | ([.assignees.nodes[].login]) as $who
      | ([.labels.nodes[].name] | skiplabel) as $skip
      | {
          number, title,
          sort: [ (if .milestone == null then "2" elif .milestone.dueOn == null then "1" else "0" + .milestone.dueOn end), .number ],
          status: (
            if $skip != null then ["skipped", $skip]
            elif ($prs | length) > 0 then ["has-pr", ($prs | join(","))]
            elif ($who | length) > 0 and ($who | index($me)) == null then ["assigned", ($who | join(","))]
            elif .subIssuesSummary.total > .subIssuesSummary.completed then ["tracking", "\(.subIssuesSummary.total - .subIssuesSummary.completed) open sub-issues"]
            elif ([.labels.nodes[].name] | any(test("^(tracking|epic|roadmap|meta)$"; "i"))) or (.title | test("\\b(tracking|epic|roadmap)\\b"; "i"))
              then ["tracking", "tracking/epic issue"]
            elif ($blockers | length) > 0 then ["blocked", ($blockers | join(","))]
            else ["ready", "-"] end)
        })
    | sort_by(.sort)
    | .[] | [.number, .status[0], .status[1], .title] | @tsv'

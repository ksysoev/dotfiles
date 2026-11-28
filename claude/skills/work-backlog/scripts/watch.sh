#!/usr/bin/env bash
# watch.sh <state-dir> <owner/repo> <milestone-or-""> <parallel>
#
# Waits until something needs the orchestrator, prints one line per event and
# exits. Run it in the background; it is silent while nothing changes.
#
#   finished <issue> <session> <first line of result.md>
#   needs-input <issue> <session>      the session is waiting for the user
#   ended <issue> <session> <state>    the session failed or was stopped, no result
#   stalled <issue> <session>          idle for STALL_MIN minutes without a result
#   ready <issue> [<issue>...]         issues that can start, when a slot is free
#
# A session's result is <git-common-dir>/implement-issue/<issue>/result.md,
# which implement-issue writes as its very last step. A session can look idle
# while it waits on a background job (CI), so idle alone is not "finished".
#
# Reported states are written back to sessions.tsv so an event is printed once.
set -uo pipefail

state="${1:?usage: watch.sh <state-dir> <owner/repo> <milestone> <parallel>}"
repo="${2:?missing repo}"
milestone="${3:-}"
parallel="${4:-1}"

POLL_SEC="${POLL_SEC:-30}"
READY_EVERY_SEC="${READY_EVERY_SEC:-300}"
STALL_MIN="${STALL_MIN:-20}"

here="$(cd "$(dirname "$0")" && pwd)"
common="$(git rev-parse --path-format=absolute --git-common-dir)"
sessions="$state/sessions.tsv"
handled="$state/handled.txt"
touch "$sessions" "$handled"

last_ready_check=0

while true; do
  agents="$(claude agents --json --all 2>/dev/null || echo '[]')"
  now="$(date +%s)"
  events=()
  tmp="$(mktemp)"
  active=0

  while IFS=$'\t' read -r issue id reported since; do
    [ -z "${issue:-}" ] && continue
    cur="$(jq -r --arg id "$id" '[.[] | select(.id == $id)][0].state // "gone"' <<<"$agents")"
    result="$common/implement-issue/$issue/result.md"
    new="$reported"

    if [ -s "$result" ]; then
      if [ "$reported" != "finished" ]; then
        events+=("finished $issue $id $(head -n1 "$result")")
        new="finished"
      fi
    else
      case "$cur" in
        blocked)
          [ "$reported" != "needs-input" ] && events+=("needs-input $issue $id")
          new="needs-input" since="-" ;;
        failed | stopped | gone)
          [ "$reported" != "ended" ] && events+=("ended $issue $id $cur")
          new="ended" ;;
        done)
          [ "$since" = "-" ] && since="$now"
          if [ $((now - since)) -ge $((STALL_MIN * 60)) ] && [ "$reported" != "stalled" ]; then
            events+=("stalled $issue $id")
            new="stalled"
          fi ;;
        *)
          new="working" since="-" ;;
      esac
    fi

    case "$new" in finished | ended) ;; *) active=$((active + 1)) ;; esac
    printf '%s\t%s\t%s\t%s\n' "$issue" "$id" "$new" "$since" >>"$tmp"
  done <"$sessions"
  mv "$tmp" "$sessions"

  free=$((parallel - active))
  if [ "$free" -gt 0 ] && [ $((now - last_ready_check)) -ge "$READY_EVERY_SEC" ]; then
    last_ready_check="$now"
    taken="$(cut -f1 "$sessions"; cat "$handled")"
    ready="$("$here/backlog.sh" "$repo" "$milestone" 2>/dev/null |
      awk -F'\t' '$2 == "ready" {print $1}' |
      grep -vxF -f <(printf '%s\n' "$taken" | grep . || echo __none__) |
      head -n "$free" | tr '\n' ' ')"
    [ -n "${ready// /}" ] && events+=("ready ${ready% }")
  fi

  if [ "${#events[@]}" -gt 0 ]; then
    printf '%s\n' "${events[@]}"
    exit 0
  fi
  sleep "$POLL_SEC"
done

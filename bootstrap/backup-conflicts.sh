#!/usr/bin/env bash
# pre-dotfiles hook for `mise bootstrap`.
#
# mise refuses to replace a real file with a [dotfiles] symlink, and its
# --force-dotfiles flag deletes the file without a backup. This hook moves
# anything that would block a symlink aside to <target>.bak.<timestamp>, so
# the dotfiles step can then link cleanly and nothing is lost.
set -euo pipefail

if ! command -v jq >/dev/null; then
  echo "backup-conflicts: jq not found (ships with macOS 15+)" >&2
  exit 1
fi

stamp="$(date +%Y%m%d-%H%M%S)"

# One line per symlink entry: <absolute target>\t<absolute source>
mise dot status --json |
  jq -r --arg home "$HOME" '
    .files[]
    | select(.mode == "symlink")
    | [(.target | sub("^~"; $home)), .origin.source]
    | @tsv' |
  while IFS=$'\t' read -r target source; do
    # Nothing there yet, or already the right link: nothing to back up.
    [[ -e "$target" || -L "$target" ]] || continue
    [[ -L "$target" && "$(readlink "$target")" == "$source" ]] && continue

    backup="$target.bak.$stamp"
    if [[ -e "$backup" || -L "$backup" ]]; then
      echo "backup-conflicts: refusing, $backup already exists" >&2
      exit 1
    fi
    mv -- "$target" "$backup"
    echo "backup   ${target/#$HOME/~} -> ${backup/#$HOME/~}"
  done

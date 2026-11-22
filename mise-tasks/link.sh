#!/usr/bin/env bash
# Symlink dotfiles from this repo into $HOME.
#   link.sh          create/repair links; existing files are moved to <file>.bak.<timestamp>
#   link.sh --check  only report status; exits 1 if anything is not linked
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK=false
[[ "${1:-}" == "--check" ]] && CHECK=true

# Paths relative to both the repo root and $HOME.
LINKS=(
  .zshrc
  .gitignore_global
  .config/nvim
  .config/mise
)

# backup moves $HOME/<rel> aside to a unique timestamped path, so an existing
# backup is never overwritten and a directory is never moved into another one.
backup() {
  local rel="$1" bak
  bak="$rel.bak.$(date +%Y%m%d-%H%M%S)"
  if [[ -e "$HOME/$bak" || -L "$HOME/$bak" ]]; then
    echo "ERROR    backup target exists: $bak" >&2
    return 1
  fi
  mv -- "$HOME/$rel" "$HOME/$bak"
  echo "backup   $rel -> $bak"
}

status=0
for rel in "${LINKS[@]}"; do
  src="$REPO/$rel"
  dst="$HOME/$rel"

  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    echo "ok       $rel"
    continue
  fi

  if $CHECK; then
    echo "MISSING  $rel"
    status=1
    continue
  fi

  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" || -L "$dst" ]]; then
    backup "$rel"
  fi
  ln -s "$src" "$dst"
  echo "linked   $rel"
done

exit "$status"

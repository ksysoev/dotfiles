#!/usr/bin/env bash
# Symlink dotfiles from this repo into $HOME.
#   link.sh          create/repair links; existing real files are moved to <file>.bak
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
    mv "$dst" "$dst.bak"
    echo "backup   $rel -> $rel.bak"
  fi
  ln -s "$src" "$dst"
  echo "linked   $rel"
done

exit "$status"

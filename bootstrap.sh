#!/usr/bin/env bash
# Set up a new Mac from this repo:
#
#   curl -fsSL https://raw.githubusercontent.com/ksysoev/dotfiles/main/bootstrap.sh | bash
#
# 1. Installs the Xcode Command Line Tools (git, compilers) without the GUI dialog
# 2. Installs mise
# 3. Runs `mise bootstrap`, which clones this repo to ~/Documents/Dev/dotfiles and
#    applies .config/mise/config.toml: packages, repos, dotfiles, macOS settings,
#    tools and the bootstrap task.
#
# Safe to run again. Extra arguments go to `mise bootstrap` (e.g. --dry-run).
set -euo pipefail

REPO_URL="${DOTFILES_REPO:-https://github.com/ksysoev/dotfiles.git}"
REPO_DIR="$HOME/Documents/Dev/dotfiles"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "bootstrap.sh is for macOS" >&2
  exit 1
fi
# macOS 15+ ships /usr/bin/jq (used by the dotfiles backup hook).
if (($(sw_vers -productVersion | cut -d. -f1) < 15)); then
  echo "bootstrap.sh needs macOS 15 or later (found $(sw_vers -productVersion))" >&2
  exit 1
fi

# --- 1. Xcode Command Line Tools ---------------------------------------------
if ! xcode-select -p >/dev/null 2>&1; then
  log "Installing Xcode Command Line Tools (needs sudo)"
  # This marker file makes softwareupdate list the CLT package.
  marker=/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  touch "$marker"
  trap 'rm -f "$marker"' EXIT # remove it even if a step below fails
  # macOS's own sort supports -V (version order).
  label="$(softwareupdate --list 2>/dev/null |
    sed -n 's/^\* Label: \(Command Line Tools.*\)$/\1/p' | sort -V | tail -n1)" || true
  if [[ -n "$label" ]]; then
    # On failure, fall through to the GUI installer below instead of exiting.
    sudo softwareupdate --install "$label" --verbose || true
  fi
  rm -f "$marker"
  trap - EXIT
  if ! xcode-select -p >/dev/null 2>&1; then
    # Fall back to the GUI installer and wait for it.
    xcode-select --install || true
    echo "Finish the Command Line Tools install in the dialog, then run this script again." >&2
    exit 1
  fi
fi

# --- 2. mise -----------------------------------------------------------------
export PATH="$HOME/.local/bin:$PATH"
if ! command -v mise >/dev/null; then
  log "Installing mise"
  curl -fsSL https://mise.run | sh
fi

# --- 3. mise bootstrap -------------------------------------------------------
log "Running mise bootstrap"
# Clones the repo on the first run and reuses the checkout afterwards. mise
# requires --from to match the checkout's origin exactly (SSH and HTTPS differ),
# so an existing checkout's own origin is used.
if [[ -d "$REPO_DIR/.git" ]]; then
  REPO_URL="$(git -C "$REPO_DIR" remote get-url origin)"
fi
mise bootstrap --yes \
  --from "$REPO_URL" --from-dir "$REPO_DIR" --config-dir .config/mise "$@"

log "Done. Log out and back in so keyboard and other macOS settings take effect."

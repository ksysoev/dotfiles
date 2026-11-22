#!/usr/bin/env bash
# Sync SSH keys between ~/.ssh and a backup folder in iCloud Drive.
# Runs as a post-dotfiles hook of `mise bootstrap`.
#
#   ssh-keys.sh <key name>...      e.g. ssh-keys.sh github_ed25519 digitalocean_ed25519
#
# For each key (private key plus its .pub):
#   only in iCloud      -> restore it to ~/.ssh
#   only in ~/.ssh      -> back it up to iCloud (only if passphrase-protected)
#   in both, identical  -> nothing to do
#   in both, different  -> warn and leave both alone
#
# Passphrases are never stored here; they live in the macOS Keychain. A restored
# key needs one `ssh-add --apple-use-keychain` unless Keychain already has its
# passphrase (for example through iCloud Keychain). Problems produce warnings
# but never fail the bootstrap.
set -uo pipefail

ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
BACKUP="${SSH_KEYS_BACKUP_DIR:-$ICLOUD/Backups/ssh}"
SSH_DIR="$HOME/.ssh"

say() { echo "ssh-keys: $*"; }
short() { local p="${1/#$ICLOUD/iCloud Drive}"; echo "${p/#$HOME/~}"; }

if [[ $# -eq 0 ]]; then
  say "usage: ssh-keys.sh <key name>..." >&2
  exit 0
fi
if [[ ! -d "$ICLOUD" ]]; then
  say "iCloud Drive not found; sign in to iCloud and enable iCloud Drive, then run mise bootstrap again"
  exit 0
fi

mkdir -p "$BACKUP" "$SSH_DIR"
chmod 700 "$SSH_DIR"

is_dataless() { [[ "$(stat -f %Sf "$1" 2>/dev/null)" == *dataless* ]]; }

# iCloud may keep files only in the cloud ("dataless") until opened. Ask for a
# download and wait a while so a fresh Mac can restore on the first run.
materialize() {
  local f="$1" i
  [[ -e "$f" ]] || return 1
  is_dataless "$f" || return 0
  brctl download "$f" >/dev/null 2>&1
  for ((i = 0; i < 120; i++)); do
    is_dataless "$f" || return 0
    sleep 1
  done
  say "timed out downloading $(short "$f") from iCloud"
  return 1
}

has_passphrase() { ! ssh-keygen -y -P '' -f "$1" >/dev/null 2>&1; }

restored=()
for key in "$@"; do
  # Never back up a private key without a passphrase (nor its .pub).
  if [[ -e "$SSH_DIR/$key" && ! -e "$BACKUP/$key" ]] && ! has_passphrase "$SSH_DIR/$key"; then
    say "WARNING: not backing up $(short "$SSH_DIR/$key"): it has no passphrase (add one with ssh-keygen -p -f $(short "$SSH_DIR/$key"))"
    continue
  fi
  for f in "$key" "$key.pub"; do
    local_f="$SSH_DIR/$f"
    cloud_f="$BACKUP/$f"
    [[ -e "$cloud_f" ]] && ! materialize "$cloud_f" && continue

    if [[ -e "$local_f" && -e "$cloud_f" ]]; then
      cmp -s "$local_f" "$cloud_f" ||
        say "WARNING: $(short "$local_f") differs from the iCloud backup; leaving both unchanged"
    elif [[ -e "$cloud_f" ]]; then
      cp -p "$cloud_f" "$local_f"
      if [[ "$f" == *.pub ]]; then chmod 644 "$local_f"; else chmod 600 "$local_f"; fi
      say "restored $(short "$local_f") from iCloud"
      [[ "$f" == *.pub ]] || restored+=("$local_f")
    elif [[ -e "$local_f" ]]; then
      cp -p "$local_f" "$cloud_f"
      chmod 600 "$cloud_f"
      say "backed up $(short "$local_f") to $(short "$cloud_f")"
    else
      say "WARNING: $f is neither in ~/.ssh nor in the iCloud backup"
    fi
  done
done

# Load restored keys whose passphrases Keychain already knows; list the rest.
if ((${#restored[@]})); then
  ssh-add --apple-load-keychain </dev/null >/dev/null 2>&1
  missing=()
  for k in "${restored[@]}"; do
    fp="$(ssh-keygen -lf "$k.pub" 2>/dev/null | awk '{print $2}')"
    ssh-add -l 2>/dev/null | grep -qF "$fp" || missing+=("$(short "$k")")
  done
  if ((${#missing[@]})); then
    say "store the passphrases in Keychain once (asks for each passphrase):"
    say "  ssh-add --apple-use-keychain ${missing[*]}"
  fi
fi
exit 0

# dotfiles

Configuration for my macOS dev machine, applied with
[`mise bootstrap`](https://mise.jdx.dev/bootstrap.html). One config file,
[`.config/mise/config.toml`](.config/mise/config.toml), declares the whole machine:

| Section | What it manages |
|---|---|
| `[tools]` | Runtimes and CLI tools (go, node, python, java, groovy, starship), pinned in `mise.lock` |
| `[bootstrap.packages]` | Homebrew formulae, taps and casks (mise installs them; no `brew` needed) |
| `[bootstrap.repos]` | Zsh plugins, as plain git checkouts in `~/.local/share/zsh/plugins` |
| `[dotfiles]` | Symlinks from `$HOME` into this repo, plus the Homebrew `PATH` line in `~/.zprofile` |
| `[bootstrap.mise_shell_activate]` | mise shims in `~/.zprofile` for login shells and GUI apps |
| `[bootstrap.settings.macos.*]` | Dock, Finder, key repeat, dark mode, hot corner, Caps Lock → Control |
| `[bootstrap.hooks]` | Backs up files that would block a symlink (`bootstrap/backup-conflicts.sh`) |
| `[tasks.bootstrap]` | Final steps: global gitignore, Neovim plugins at their `lazy-lock.json` versions |

## Setting up a new Mac

```sh
curl -fsSL https://raw.githubusercontent.com/ksysoev/dotfiles/main/bootstrap.sh | bash
```

[`bootstrap.sh`](bootstrap.sh):
1. installs the Xcode Command Line Tools (asks for your password);
2. installs mise into `~/.local/bin`;
3. runs `mise bootstrap --from <this repo>`. That clones the repo to `~/Documents/Dev/dotfiles`,
   links `~/.config/mise` to `.config/mise/` and applies everything in the table above.

Then **log out and back in** so the keyboard and other macOS settings take effect.

To see what would happen first, run the script with `--dry-run`.

If a real file is already where a symlink should go (for example a `~/.zshrc` an
installer created), the hook moves it to `<name>.bak.<timestamp>` before linking.
Nothing is deleted.

## Everyday use

All commands work from any directory.

| Command | What it does |
|---|---|
| `mise bootstrap plan` | Shows what applying would change |
| `mise bootstrap status --missing` | Drift check: lists every part, exits 1 if anything differs |
| `mise bootstrap` | Applies the config (safe to re-run) |
| `mise bootstrap --update` | Pulls this repo, then applies it |
| `mise bootstrap --only dotfiles,repos` | Applies only some parts |

### Changing tools

`~/.config/mise` is a symlink into this repo, so mise's own commands edit the tracked files:

```sh
mise use -g ripgrep@latest         # add a tool (writes config.toml + mise.lock)
mise outdated                      # updates within the configured ranges
mise outdated --bump               # include versions outside them (e.g. python 3.11 -> 3.15)
mise upgrade                       # upgrade and update mise.lock
```

Commit `.config/mise/` afterwards.

### Changing packages

Add or remove a `"brew:<formula>"` / `"brew-cask:<cask>"` line in `[bootstrap.packages]`,
then run `mise bootstrap --only packages`. Tap formulae use the full name
(`"brew:ksysoev/wsget/wsget"`).

- Removing a line does **not** uninstall the package. Run
  `mise bootstrap packages prune --manager brew --dry-run` to see unlisted packages.
- `mise bootstrap packages upgrade` upgrades them.

### Adding a dotfile

1. Put the file in the repo at the same path it has under `$HOME`.
2. Add it to `[dotfiles]` with a `~/` source path:
   `"~/.config/foo" = { source = "~/Documents/Dev/dotfiles/.config/foo" }`.
   Relative sources don't work here: they resolve against the `~/.config/mise`
   symlink and produce a link that points at itself.
3. Run `mise bootstrap --only dotfiles`.

### macOS settings

To find a value to add, change it in System Settings, then compare
`defaults read <domain>` (or `defaults -currentHost read -g`) before and after.

- The Caps Lock remap is stored per keyboard model. The built-in keyboard is
  `0-0-0`, and the external one is `<vendor>-<product>-0`.
- Values macOS stores as reals (Dock sizes, key repeat) must be written as floats, such as `44.0`.
  Otherwise `status` reports them as different.
- mise never deletes preferences, and never restarts Dock or Finder. Log out, or run
  `killall Dock Finder` after a change.

Update Neovim plugins inside nvim with `:Lazy update`, then commit `lazy-lock.json`.

## Troubleshooting

- **A tool resolves to the wrong version.** Run `type -a <tool>`. The mise copy should come
  first. Then run `mise doctor`.
- **`mise bootstrap` stops at dotfiles with "refusing to overwrite".** Something replaced a
  link after the backup hook ran. Move the file away and re-run. Don't use
  `--force-dotfiles`: it deletes the file without a backup.
- **The keyboard remap doesn't work after bootstrap.** Log out and back in, or unplug and
  replug the keyboard.

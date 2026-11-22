# dotfiles

Configuration for my macOS dev machine: zsh, Neovim (LazyVim), git, and the tool
versions installed on it.

- **[mise](https://mise.jdx.dev)** installs runtimes and CLI tools at pinned versions,
  and runs the repo tasks (`link`, `tools`, `doctor`).
- **Homebrew** installs GUI apps and system libraries.
- **Symlinks** connect each config in this repo to its place in `$HOME`.

> **Migration in progress.** The move to mise is happening in phases. Right now mise
> manages the language runtimes, and oh-my-zsh and most CLI tools still come from
> Homebrew. Some setup steps are still manual; a single `bootstrap.sh` comes later.

## Layout

| Path | Linked to | What it is |
|---|---|---|
| `.zshrc` | `~/.zshrc` | zsh config (oh-my-zsh, mise activation) |
| `.gitignore_global` | `~/.gitignore_global` | global gitignore (`core.excludesfile`) |
| `.config/nvim/` | `~/.config/nvim` | LazyVim config; plugin versions pinned in `lazy-lock.json` |
| `.config/mise/` | `~/.config/mise` | global mise tools (`config.toml`) and exact versions (`mise.lock`) |
| `.oh-my-zsh/custom/plugins/` | via `ZSH_CUSTOM` | zsh plugins as git submodules |
| `.Brewfile` | not linked | Homebrew packages |
| `mise.toml` | not linked | repo tasks |
| `mise-tasks/` | not linked | scripts the tasks run |

## Setting up a new machine

The repo **must be cloned to `~/Documents/Dev/dotfiles`**, because `ZSH_CUSTOM` in
`.zshrc` points there.

```sh
# 1. Command line tools and Homebrew
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install mise

# 2. Clone with submodules. Use HTTPS here: SSH keys and 1Password aren't set up yet.
git clone --recurse-submodules https://github.com/ksysoev/dotfiles.git ~/Documents/Dev/dotfiles
cd ~/Documents/Dev/dotfiles

# 3. oh-my-zsh, without letting it replace .zshrc
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc

# 4. Link configs, install tools and packages
mise trust                         # allow this repo's mise.toml to run tasks
mise run link                      # symlink configs into $HOME
mise run tools                     # install runtimes from mise.lock
brew bundle --file=.Brewfile       # Homebrew packages
git config --global core.excludesfile ~/.gitignore_global

# 5. Start a new shell and install Neovim plugins at their pinned versions
exec zsh
nvim --headless "+Lazy! restore" +qa
```

`mise run link` never deletes anything. If a real file or folder is already where a
link should go, it renames it to `<name>.bak.<timestamp>` first.

## Everyday use

Run `mise tasks` to list the tasks. They're defined in `mise.toml` and run from the
repo root.

| Command | What it does |
|---|---|
| `mise run doctor` | Checks that every link is in place (`link.sh --check`) and runs `mise doctor` |
| `mise run link` | Creates or repairs symlinks; safe to run again |
| `mise run tools` | Installs anything in the mise config that's missing |

### Adding or changing a tool

`~/.config/mise` is a symlink into this repo, so `mise use -g` edits the tracked config:

```sh
mise use -g ripgrep@latest     # adds it to .config/mise/config.toml and mise.lock
git add .config/mise && git commit -m "Add ripgrep"
```

### Updating tools

```sh
mise outdated                  # see what's newer within the configured ranges
mise outdated --bump           # include versions outside the ranges
mise upgrade                   # upgrade within the configured ranges; updates mise.lock
mise upgrade --bump            # also move past ranges (e.g. python 3.11 -> 3.12)
```

Commit `.config/mise/mise.lock` afterwards so other machines get the same versions.
Update Neovim plugins inside nvim with `:Lazy update`, then commit `lazy-lock.json`.

### Adding a new dotfile

1. Put the file in the repo at the same path it has under `$HOME`, for example
   `.config/starship.toml`.
2. Add that path to the `LINKS` list in `mise-tasks/link.sh`.
3. Run `mise run link`. If a real file is already there, it's renamed to `.bak.<timestamp>`.

## Troubleshooting

- **A tool resolves to the wrong version or path.** Run `type -a <tool>`; the mise copy
  should come first. Then run `mise doctor`.
- **`mise run` says the config isn't trusted.** Run `mise trust` in the repo root.
- **`command not found: mise` errors.** These shouldn't appear: `.zshrc` skips mise when
  it isn't installed. Install it with `brew install mise`.

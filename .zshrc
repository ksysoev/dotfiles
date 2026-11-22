# zsh config. Plugins are plain git checkouts managed by `mise bootstrap`
# ([bootstrap.repos] in ~/.config/mise/config.toml); the prompt is starship.

# --- PATH --------------------------------------------------------------------
path=(
  /opt/homebrew/bin
  /opt/homebrew/sbin
  /opt/homebrew/opt/gnu-sed/libexec/gnubin
  $path
)
typeset -U path  # drop duplicates

# --- History -----------------------------------------------------------------
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=10000
setopt extended_history       # save timestamps
setopt hist_expire_dups_first # drop duplicates first when trimming
setopt hist_ignore_dups       # don't record a command twice in a row
setopt hist_ignore_space      # commands starting with a space aren't saved
setopt hist_verify            # show !! expansions before running
setopt share_history          # share history between open shells
setopt interactive_comments

# --- Keys --------------------------------------------------------------------
bindkey -e
# Up/Down search history for commands starting with what's typed
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search

# --- Completion --------------------------------------------------------------
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'

# --- Aliases -----------------------------------------------------------------
alias ls="lsd"
alias gco="git checkout"

# Colored man pages
man() {
  LESS_TERMCAP_md=$'\e[1;31m' LESS_TERMCAP_me=$'\e[0m' \
  LESS_TERMCAP_us=$'\e[1;32m' LESS_TERMCAP_ue=$'\e[0m' \
  LESS_TERMCAP_so=$'\e[1;33m' LESS_TERMCAP_se=$'\e[0m' \
  command man "$@"
}

# --- Tools -------------------------------------------------------------------
# mise: tool versions and env from ~/.config/mise/config.toml.
# Before starship, which mise installs.
if (( $+commands[mise] )); then
  eval "$(mise activate zsh)"
  eval "$(mise hook-env -s zsh)"  # put mise tools on PATH now, not at first prompt
fi

if (( $+commands[starship] )); then
  eval "$(starship init zsh)"
fi

# --- Plugins (syntax highlighting must be last) ------------------------------
_zsh_plugins=~/.local/share/zsh/plugins
for _plugin in zsh-autosuggestions/zsh-autosuggestions.zsh \
               zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
  [[ -r $_zsh_plugins/$_plugin ]] && source $_zsh_plugins/$_plugin
done
unset _zsh_plugins _plugin

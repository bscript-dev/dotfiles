# ~/.zshrc — interactive shell config
# Managed by the dotfiles repo (symlink). Edit it there, not in $HOME.
#
# Rule for this file: NOTHING here may depend on a specific OS.
# Every external tool is loaded behind a guard (does it exist? then load it).
# Machine-specific things go to ~/.zshrc.local (see .zshrc.local.example).

# --- Powerlevel10k instant prompt --------------------------------------------
# Must stay near the top. Anything that can ask for input (passwords, [y/n]
# confirmations) has to go ABOVE this block.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# --- Oh My Zsh ---------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  colored-man-pages
  colorize
  pip
  python
  zsh-syntax-highlighting   # custom plugin — installed by install.sh
  zsh-autosuggestions       # custom plugin — installed by install.sh
  ng
  yarn
  docker
)

# Guard: a workspace where the Oh My Zsh clone failed still gets a working shell
# (PATH, functions, nvm) instead of an error on every prompt.
if [ -f "$ZSH/oh-my-zsh.sh" ]; then
  source "$ZSH/oh-my-zsh.sh"
fi

# --- Node / nvm --------------------------------------------------------------
# Two install layouts: the official installer (~/.nvm) or Homebrew (macOS).
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
elif [ -s "${HOMEBREW_PREFIX:-/nonexistent}/opt/nvm/nvm.sh" ]; then
  \. "${HOMEBREW_PREFIX}/opt/nvm/nvm.sh"
  [ -s "${HOMEBREW_PREFIX}/opt/nvm/etc/bash_completion.d/nvm" ] && \. "${HOMEBREW_PREFIX}/opt/nvm/etc/bash_completion.d/nvm"
fi

# --- Java / jenv -------------------------------------------------------------
if command -v jenv >/dev/null 2>&1; then
  eval "$(jenv init -)"
  [ -d "$HOME/.jenv/shims" ] && export PATH="$HOME/.jenv/shims:$PATH"
fi

# --- Google Cloud SDK --------------------------------------------------------
[ -f "$HOME/google-cloud-sdk/path.zsh.inc" ] && . "$HOME/google-cloud-sdk/path.zsh.inc"
[ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ] && . "$HOME/google-cloud-sdk/completion.zsh.inc"

# --- PATH --------------------------------------------------------------------
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"

# --- Prompt ------------------------------------------------------------------
# To change the look: `p10k configure` (it overwrites ~/.p10k.zsh — copy it back to the repo).
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# --- Functions: Docker -------------------------------------------------------
# List containers: ID + image. Flags: -s status, -n names, -p ports, -e exited only.
b_dcls() {
  local fmt="table {{.ID}}\t{{.Image}}"
  local args=()
  for a in "$@"; do
    case "$a" in
      -s) fmt+="\t{{.Status}}" ;;
      -n) fmt+="\t{{.Names}}"  ;;
      -p) fmt+="\t{{.Ports}}"  ;;
      -e) args+=(-a --filter "status=exited") ;;
      *)  args+=("$a")         ;;
    esac
  done
  docker container ls --format "$fmt" "${args[@]}"
}

# --- Functions: Git ----------------------------------------------------------
# Commit graph of every branch, one line per commit.
b_graph() {
  git log --oneline --graph --decorate --all
}

# --- Local, unversioned extensions -------------------------------------------
# OS paths (Homebrew, JetBrains), tokens, per-machine settings.
# (an `if`, not `&&` — otherwise a missing file leaves exit code 1 on the first prompt)
if [ -f "$HOME/.zshrc.local" ]; then
  source "$HOME/.zshrc.local"
fi

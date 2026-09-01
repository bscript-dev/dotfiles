#!/usr/bin/env bash
# Bootstrap dotfiles — macOS, Linux, and remote dev workspaces (Coder, Codespaces).
#
# Usage:
#   ./install.sh            — link config, then install Oh My Zsh, the p10k theme and plugins
#   ./install.sh --dry-run  — only print what it would do
#   ./install.sh --no-shell — skip changing the login shell
#
# Design rules, in this order of importance:
#   1. Symlinks run BEFORE anything that touches the network. A workspace with a
#      blocked or flaky network still ends up with your shell config.
#   2. Every network step is non-fatal. A failed clone costs you the prompt theme,
#      not the whole setup.
#   3. .zshrc guards its Oh My Zsh source, so even a half-installed state opens a
#      working shell instead of erroring on every prompt.
#
# Idempotent: existing real files are moved to ~/.dotfiles-backup/<timestamp>/
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
DRY_RUN=false
SET_SHELL=true

for arg in "$@"; do
  case "$arg" in
    --dry-run)  DRY_RUN=true ;;
    --no-shell) SET_SHELL=false ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

# source (in the repo) -> target (in $HOME)
LINKS=(
  "zsh/.zshrc:.zshrc"
  "zsh/.p10k.zsh:.p10k.zsh"
)

info() { printf '\033[0;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m  ok\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m  !!\033[0m %s\n' "$*"; }

# run: aborts the script on failure (used where failure means a broken result)
run() { if $DRY_RUN; then echo "  [dry-run] $*"; else "$@"; fi; }

# try: never aborts the script (used for everything that needs the network)
try() {
  if $DRY_RUN; then echo "  [dry-run] $*"; return 0; fi
  if "$@" >/dev/null 2>&1; then return 0; fi
  warn "failed, continuing without it: $*"
  return 1
}

# Non-interactive privilege escalation, or nothing. Never prompts for a password:
# a workspace bootstrap that blocks on a prompt hangs the whole provisioning step.
if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
  CAN_ROOT=true
elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
  SUDO="sudo -n"
  CAN_ROOT=true
else
  SUDO=""
  CAN_ROOT=false
fi

# --- 1. Requirements ----------------------------------------------------------
info "Requirements"

install_pkg() {  # $1 = package name; returns non-zero if it cannot install
  $CAN_ROOT || return 1
  if   command -v apt-get >/dev/null 2>&1; then $SUDO apt-get update -qq && $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$1"
  elif command -v dnf     >/dev/null 2>&1; then $SUDO dnf install -y -q "$1"
  elif command -v yum     >/dev/null 2>&1; then $SUDO yum install -y -q "$1"
  elif command -v apk     >/dev/null 2>&1; then $SUDO apk add --no-cache "$1"
  elif command -v pacman  >/dev/null 2>&1; then $SUDO pacman -Sy --noconfirm "$1"
  elif command -v zypper  >/dev/null 2>&1; then $SUDO zypper --non-interactive install "$1"
  else return 1
  fi
}

for bin in zsh git curl; do
  if command -v "$bin" >/dev/null 2>&1; then
    ok "$bin"
  elif try install_pkg "$bin"; then
    ok "$bin (installed)"
  else
    warn "missing: $bin — install it by hand (no package manager, or no passwordless root)"
  fi
done

# --- 2. Symlinks (no network — runs first on purpose) -------------------------
info "Symlinks"
for pair in "${LINKS[@]}"; do
  src="$DOTFILES/${pair%%:*}"
  dst="$HOME/${pair##*:}"

  [ -e "$src" ] || { warn "missing source: $src — skipping"; continue; }

  dst_dir="$(dirname "$dst")"
  [ -d "$dst_dir" ] || run mkdir -p "$dst_dir"

  # already points where it should?
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    ok "${pair##*:}"
    continue
  fi

  # an existing real file -> back it up
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    run mkdir -p "$BACKUP/$(dirname "${pair##*:}")"
    run mv "$dst" "$BACKUP/${pair##*:}"
    warn "backup: ${pair##*:} -> $BACKUP/${pair##*:}"
  fi

  run ln -s "$src" "$dst"
  ok "${pair##*:} -> $src"
done

# --- 3. Oh My Zsh + theme + plugins (network — all of it non-fatal) -----------
info "Oh My Zsh"
ZSH_DIR="$HOME/.oh-my-zsh"
if [ -d "$ZSH_DIR" ]; then
  ok "already installed"
elif try sh -c 'RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'; then
  ok "installed"
else
  warn "no Oh My Zsh — .zshrc skips it and you get a plain zsh with the PATH and functions"
fi

CUSTOM="${ZSH_CUSTOM:-$ZSH_DIR/custom}"
clone_if_missing() {  # $1 = repo URL, $2 = target directory
  if [ -d "$2" ]; then
    ok "$(basename "$2") already there"
  elif try git clone --depth=1 "$1" "$2"; then
    ok "$(basename "$2")"
  fi
}
clone_if_missing https://github.com/romkatv/powerlevel10k.git             "$CUSTOM/themes/powerlevel10k"
clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting.git "$CUSTOM/plugins/zsh-syntax-highlighting"
clone_if_missing https://github.com/zsh-users/zsh-autosuggestions.git     "$CUSTOM/plugins/zsh-autosuggestions"

# --- 4. Login shell -----------------------------------------------------------
# Without this the config is in place but never read: most images drop you in bash.
info "Login shell"
ZSH_BIN="$(command -v zsh || true)"
if ! $SET_SHELL; then
  ok "skipped (--no-shell)"
elif [ -z "$ZSH_BIN" ]; then
  warn "zsh not installed — nothing to switch to"
elif [ "$(basename "${SHELL:-}")" = "zsh" ]; then
  # any zsh counts — the point is not to land in bash, not to prefer one build
  ok "already zsh (${SHELL})"
elif ! $CAN_ROOT; then
  warn "cannot switch without a password — run by hand: chsh -s $ZSH_BIN"
else
  # chsh refuses a shell that is not listed in /etc/shells
  if [ -f /etc/shells ] && ! grep -qx "$ZSH_BIN" /etc/shells; then
    run sh -c "echo '$ZSH_BIN' | $SUDO tee -a /etc/shells >/dev/null"
  fi
  if try $SUDO chsh -s "$ZSH_BIN" "$(id -un)"; then
    ok "default shell -> $ZSH_BIN (applies on next login)"
  else
    warn "chsh failed — run by hand: chsh -s $ZSH_BIN"
  fi
fi

# --- 5. Fill in by hand -------------------------------------------------------
info "Local and secret — the repo does not carry these"
if [ -f "$HOME/.zshrc.local" ]; then
  ok "~/.zshrc.local"
else
  warn "~/.zshrc.local — OS-specific paths (Homebrew, JetBrains); template: zsh/.zshrc.local.example"
fi
[ -f "$HOME/.npmrc" ] && ok "~/.npmrc" || warn "~/.npmrc — npm token (template: .npmrc.example)"

# without a Nerd Font p10k renders boxes instead of icons
info "Font"
warn "the prompt needs a Nerd Font (e.g. MesloLGS NF) selected in your terminal"

echo
info "Done. Open a new terminal, or run: exec zsh"

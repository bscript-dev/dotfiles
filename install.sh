#!/usr/bin/env bash
# Bootstrap dotfiles — macOS and Linux.
#
# Usage:
#   ./install.sh            — symlinks + Oh My Zsh, the p10k theme and zsh plugins
#   ./install.sh --dry-run  — only print what it would do
#
# Idempotent: existing real files are moved to ~/.dotfiles-backup/<timestamp>/
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
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
run()  { if $DRY_RUN; then echo "  [dry-run] $*"; else "$@"; fi; }

# --- 1. Requirements ----------------------------------------------------------
info "Requirements"
for bin in zsh git curl; do
  if command -v "$bin" >/dev/null 2>&1; then
    ok "$bin"
  else
    warn "missing: $bin — install it before continuing"
  fi
done

# --- 2. Oh My Zsh + theme + plugins ------------------------------------------
info "Oh My Zsh"
ZSH_DIR="$HOME/.oh-my-zsh"
if [ -d "$ZSH_DIR" ]; then
  ok "already installed"
else
  run sh -c 'RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
fi

CUSTOM="${ZSH_CUSTOM:-$ZSH_DIR/custom}"
clone_if_missing() {  # $1 = repo URL, $2 = target directory
  if [ -d "$2" ]; then
    ok "$(basename "$2") already there"
  else
    run git clone --depth=1 "$1" "$2"
  fi
}
clone_if_missing https://github.com/romkatv/powerlevel10k.git             "$CUSTOM/themes/powerlevel10k"
clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting.git "$CUSTOM/plugins/zsh-syntax-highlighting"
clone_if_missing https://github.com/zsh-users/zsh-autosuggestions.git     "$CUSTOM/plugins/zsh-autosuggestions"

# --- 3. Symlinks --------------------------------------------------------------
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

# --- 4. Fill in by hand -------------------------------------------------------
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

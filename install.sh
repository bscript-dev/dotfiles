#!/usr/bin/env bash
# Bootstrap dotfiles — macOS i Linux.
#
# Użycie:
#   ./install.sh            — symlinki + Oh My Zsh, motyw p10k i pluginy zsh
#   ./install.sh --dry-run  — tylko pokaż, co by zrobił
#
# Idempotentny: istniejące prawdziwe pliki lądują w ~/.dotfiles-backup/<data>/
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) echo "Nieznana opcja: $arg" >&2; exit 1 ;;
  esac
done

# źródło (w repo) -> cel (w $HOME)
LINKS=(
  "zsh/.zshrc:.zshrc"
  "zsh/.p10k.zsh:.p10k.zsh"
  "git/.gitconfig:.gitconfig"
  "git/ignore:.config/git/ignore"
)

info() { printf '\033[0;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m  ok\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m  !!\033[0m %s\n' "$*"; }
run()  { if $DRY_RUN; then echo "  [dry-run] $*"; else "$@"; fi; }

# --- 1. Wymagania -------------------------------------------------------------
info "Wymagania"
for bin in zsh git curl; do
  if command -v "$bin" >/dev/null 2>&1; then
    ok "$bin"
  else
    warn "brak: $bin — zainstaluj przed dalszym ciągiem"
  fi
done

# --- 2. Oh My Zsh + motyw + pluginy ------------------------------------------
info "Oh My Zsh"
ZSH_DIR="$HOME/.oh-my-zsh"
if [ -d "$ZSH_DIR" ]; then
  ok "już jest"
else
  run sh -c 'RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
fi

CUSTOM="${ZSH_CUSTOM:-$ZSH_DIR/custom}"
clone_if_missing() {  # $1 = repo URL, $2 = katalog docelowy
  if [ -d "$2" ]; then
    ok "$(basename "$2") już jest"
  else
    run git clone --depth=1 "$1" "$2"
  fi
}
clone_if_missing https://github.com/romkatv/powerlevel10k.git             "$CUSTOM/themes/powerlevel10k"
clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting.git "$CUSTOM/plugins/zsh-syntax-highlighting"
clone_if_missing https://github.com/zsh-users/zsh-autosuggestions.git     "$CUSTOM/plugins/zsh-autosuggestions"

# --- 3. Symlinki --------------------------------------------------------------
info "Symlinki"
for pair in "${LINKS[@]}"; do
  src="$DOTFILES/${pair%%:*}"
  dst="$HOME/${pair##*:}"

  [ -e "$src" ] || { warn "brak źródła: $src — pomijam"; continue; }

  dst_dir="$(dirname "$dst")"
  [ -d "$dst_dir" ] || run mkdir -p "$dst_dir"

  # już wskazuje tam, gdzie trzeba?
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    ok "${pair##*:}"
    continue
  fi

  # istniejący prawdziwy plik -> backup
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    run mkdir -p "$BACKUP/$(dirname "${pair##*:}")"
    run mv "$dst" "$BACKUP/${pair##*:}"
    warn "backup: ${pair##*:} -> $BACKUP/${pair##*:}"
  fi

  run ln -s "$src" "$dst"
  ok "${pair##*:} -> $src"
done

# --- 4. Do uzupełnienia ręcznie ----------------------------------------------
info "Lokalne i tajne — repo tego nie niesie"
if [ -f "$HOME/.zshrc.local" ]; then
  ok "~/.zshrc.local"
else
  warn "~/.zshrc.local — ścieżki systemowe (Homebrew, JetBrains); szablon: zsh/.zshrc.local.example"
fi
if [ -f "$HOME/.gitconfig.local" ]; then
  ok "~/.gitconfig.local"
else
  warn "~/.gitconfig.local — tożsamość gita; BEZ TEGO \`git commit\` odmówi. Szablon: git/.gitconfig.local.example"
fi
[ -f "$HOME/.npmrc" ]          && ok "~/.npmrc"          || warn "~/.npmrc — token npm (szablon: .npmrc.example)"
[ -f "$HOME/.ssh/id_ed25519" ] && ok "~/.ssh/id_ed25519" || warn "~/.ssh/id_ed25519 — klucz SSH (wygeneruj: ssh-keygen -t ed25519)"

# p10k bez Nerd Fonta rysuje kwadraciki zamiast ikon
info "Font"
warn "prompt wymaga Nerd Fonta (np. MesloLGS NF) ustawionego w terminalu"

echo
info "Gotowe. Otwórz nowy terminal albo: exec zsh"

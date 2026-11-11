#!/usr/bin/env bash
set -euo pipefail

source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target="${NOCTALIA_PLUGIN_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/noctalia/plugins}/captive-portal"
check_only=false
case "${1:-}" in
  --check) check_only=true ;;
  '') ;;
  *) printf 'Usage: bash install.sh [--check]\n' >&2; exit 2 ;;
esac
for file in plugin.toml service.luau widget.luau panel.luau README.md; do
  [[ -s "$source_dir/$file" ]] || { printf 'Missing source file: %s\n' "$file" >&2; exit 1; }
done
missing=()
command -v nmcli >/dev/null || missing+=(networkmanager)
command -v notify-send >/dev/null || missing+=(libnotify)
command -v xdg-open >/dev/null || missing+=(xdg-utils)
if "$check_only"; then
  printf 'Source files: OK\nInstall destination: %s\n' "$target"
  if (("${#missing[@]}")); then printf 'Missing package: %s\n' "${missing[@]}"; fi
  if command -v noctalia >/dev/null; then noctalia plugins lint "$source_dir"; fi
  exit 0
fi
if (( EUID == 0 )); then
  printf 'Run as your regular desktop user, without sudo.\n' >&2; exit 1
fi
command -v noctalia >/dev/null || { printf 'Noctalia 5.4.0+ is required. Run this installer outside the application sandbox.\n' >&2; exit 1; }
noctalia plugins lint "$source_dir"
if (("${#missing[@]}")); then
  command -v pacman >/dev/null || { printf 'Install these packages first: %s\n' "${missing[*]}" >&2; exit 1; }
  sudo pacman -S --needed "${missing[@]}"
fi
mkdir -p -- "$(dirname -- "$target")"
if [[ -e "$target" || -L "$target" ]]; then
  [[ ! "$source_dir" -ef "$target" ]] || { printf 'Already installed.\n'; exit 0; }
  # Backups live outside the discovery directory to avoid duplicate plugin ids.
  backup_root="$(dirname -- "$target")-backups"
  mkdir -p -- "$backup_root"
  backup="$(mktemp -d "$backup_root/captive-portal.XXXXXXXX")"
  rmdir -- "$backup"
  mv -- "$target" "$backup"
  printf 'Previous installation saved: %s\n' "$backup"
fi
mkdir -- "$target"
for file in plugin.toml service.luau widget.luau panel.luau README.md; do
  install -m 644 -- "$source_dir/$file" "$target/$file"
done
install -d -- "$target/translations"
install -m 644 -- "$source_dir/translations/"*.json "$target/translations/"
printf 'Installed: %s\n' "$target"
noctalia msg config-reload
noctalia msg plugins enable r9-ferrum/captive-portal
printf 'Enabled Captive Portal. Add its portal widget in bar settings.\n'

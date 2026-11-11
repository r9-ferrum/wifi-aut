#!/usr/bin/env bash
set -euo pipefail

source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target="${NOCTALIA_PLUGIN_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/plugins}/captive-portal"
check_only=false
case "${1:-}" in
  --check) check_only=true ;;
  '') ;;
  *) printf 'Usage: bash install.sh [--check]\n' >&2; exit 2 ;;
esac
for file in manifest.json Main.qml BarWidget.qml Panel.qml README.md; do
  [[ -s "$source_dir/$file" ]] || { printf 'Missing source file: %s\n' "$file" >&2; exit 1; }
done
missing=()
command -v nmcli >/dev/null || missing+=(networkmanager)
command -v notify-send >/dev/null || missing+=(libnotify)
command -v xdg-open >/dev/null || missing+=(xdg-utils)
if "$check_only"; then
  printf 'Source files: OK\nInstall destination: %s\n' "$target"
  if ((${#missing[@]})); then printf 'Missing package: %s\n' "${missing[@]}"; fi
  exit 0
fi
if (( EUID == 0 )); then
  printf 'Run as your regular desktop user, without sudo.\n' >&2; exit 1
fi
if ((${#missing[@]})); then
  command -v pacman >/dev/null || { printf 'Install these packages first: %s\n' "${missing[*]}" >&2; exit 1; }
  printf 'Installing required packages (sudo may ask for your password).\n'
  sudo pacman -S --needed "${missing[@]}"
fi
mkdir -p -- "$(dirname -- "$target")"
if [[ -e "$target" || -L "$target" ]]; then
  [[ ! "$source_dir" -ef "$target" ]] || { printf 'Already running from the installation directory.\n'; exit 0; }
  backup="$(mktemp -d "${target}.backup.XXXXXXXX")"
  rmdir -- "$backup"
  mv -- "$target" "$backup"
  printf 'Previous installation saved: %s\n' "$backup"
fi
mkdir -- "$target"
for file in manifest.json Main.qml BarWidget.qml Panel.qml README.md; do
  install -m 644 -- "$source_dir/$file" "$target/$file"
done
printf 'Installed: %s\nRestart Noctalia and enable Captive Portal in plugin settings.\n' "$target"
printf 'NetworkManager must be running with connectivity checking enabled.\n'

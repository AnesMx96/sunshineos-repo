#!/bin/sh
# Turns an Arch Linux system into Sunshine OS. Needs only pacman and curl:
#   curl -fsSL https://raw.githubusercontent.com/tak0dan/sunshineos-repo/main/bootstrap.sh | sudo sh -s -- --loop
# Pass --convert to also switch identity, services and the boot menu (see the README), --dry-run to only look.
set -eu
[ "$(id -u)" -eq 0 ] || { echo "run as root: ... | sudo sh -s -- --loop"; exit 1; }
command -v pacman >/dev/null || { echo "this is not an Arch based system"; exit 1; }
command -v curl >/dev/null || pacman -Sy --noconfirm curl
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
curl -fsSL https://raw.githubusercontent.com/tak0dan/sunshineos-repo/main/overlay/usr/bin/sunshine-converge -o "$tmp"
chmod +x "$tmp"
exec bash "$tmp" "$@"

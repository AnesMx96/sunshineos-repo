#!/usr/bin/env bash
# Writes package-list/*.txt from a SunshineOS checkout (the ISO's own lists), so the ISO and a converted Arch system install the same set.
#   desktop.txt   Plasma desktop, apps, fonts, tools      (the ISO list from plasma-desktop on, minus installer/live-only entries)
#   hyprland.txt  the Hyprland desktop (end-4 dots) packages
# What is NOT listed on purpose: kernel, firmware, bootloader, base system, filesystem tools: a converted machine keeps its own.
# usage: scripts/gen-lists.sh /path/to/SunshineOS
set -euo pipefail
SRC=${1:?path to the SunshineOS checkout}
OUT=$(cd "$(dirname "$0")/.." && pwd)/package-list
strip() { sed 's/#.*//' "$1" | awk 'NF{print $1}'; }
{ echo "# Generated from SunshineOS/profile/packages.x86_64 by scripts/gen-lists.sh; edit the source list, not this file."
  strip "$SRC/profile/packages.x86_64" | sed -n '/^plasma-desktop$/,$p' | grep -Ev '^(calamares|archinstall)$' | awk '!s[$0]++'; } > "$OUT/desktop.txt"
{ echo "# Generated from SunshineOS/hyprland/packages.txt by scripts/gen-lists.sh."
  strip "$SRC/hyprland/packages.txt" | awk '!s[$0]++'; } > "$OUT/hyprland.txt"
wc -l "$OUT"/*.txt

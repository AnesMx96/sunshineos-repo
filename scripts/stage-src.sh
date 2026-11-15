#!/usr/bin/env bash
# Turns a SunshineOS checkout into the source tarballs of sunshine-base and sunshine-payload (one tree per package, laid out
# like the installed files). Scripts that the ISO keeps in /usr/local/bin are installed to /usr/bin, and their references are rewritten.
# usage: scripts/stage-src.sh /path/to/SunshineOS      (the payload needs a finished tools/import-end4.sh run in that checkout)
set -euo pipefail
SRC=${1:?path to the SunshineOS checkout}
HERE=$(cd "$(dirname "$0")/.." && pwd)
A=$SRC/profile/airootfs
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

# ---- sunshine-base
B=$T/base; mkdir -p "$B/usr/bin" "$B/usr/share" "$B/usr/lib/systemd/user" "$B/etc/grub.d"
for s in doctor identity info update update-notifier update-run toolbox welcome pet pods term prompt session session-notice set-shell \
         snapshot snapshots-setup cleanup boot-repair fix-pacman fastfetch-patch hyprland-install plasma-setup nixos-grub crypt-setup; do
  [ -f "$A/usr/local/bin/sunshine-$s" ] && install -m755 "$A/usr/local/bin/sunshine-$s" "$B/usr/bin/sunshine-$s" || echo "note: sunshine-$s not in the checkout"
done
cp -a "$A"/usr/bin/sunshine-store* "$B/usr/bin/"
cp -a "$A/usr/lib/sunshine-store" "$B/usr/lib/"
cp -a "$A"/usr/lib/systemd/user/sunshine-store-indexer.* "$B/usr/lib/systemd/user/"
cp -a "$A"/etc/systemd/user/sunshine-update-notifier.* "$B/usr/lib/systemd/user/"
install -m755 "$A/etc/grub.d/42_nixos" "$B/etc/grub.d/42_nixos"
for d in libalpm aurorae color-schemes icons pixmaps plasma sddm sunshine-store wallpapers; do cp -a "$A/usr/share/$d" "$B/usr/share/"; done
mkdir -p "$B/usr/share/applications" "$B/usr/share/grub"
cp -a "$A"/usr/share/applications/sunshine-*.desktop "$B/usr/share/applications/"; rm -f "$B/usr/share/applications/sunshine-install.desktop"
cp -a "$A/usr/share/grub/themes" "$B/usr/share/grub/"
rsync -a --exclude=/hyprland "$A/usr/share/sunshine/" "$B/usr/share/sunshine/"
mkdir -p "$B/usr/share/sunshine/package-lists"; cp "$HERE"/package-list/*.txt "$B/usr/share/sunshine/package-lists/"
install -m755 "$HERE"/overlay/usr/bin/sunshine-converge "$HERE"/overlay/usr/bin/sunshine-payload-apply "$B/usr/bin/"
# the live-only pieces of the hook directory: none today; the rest refers to /usr/local/bin/sunshine-*
grep -rlI '/usr/local/bin/sunshine-' "$B" 2>/dev/null | xargs -r sed -i 's#/usr/local/bin/sunshine-#/usr/bin/sunshine-#g'
tar --zstd -C "$B" -cf "$HERE/packages/sunshine-base/sunshine-base-src.tar.zst" .
echo "sunshine-base source: $(du -h "$HERE/packages/sunshine-base/sunshine-base-src.tar.zst" | cut -f1)"

# ---- sunshine-payload: the Hyprland dots, Python venv, session files (applied by sunshine-doctor / sunshine-payload-apply)
P=$A/usr/share/sunshine/hyprland
if [ -d "$P/root" ]; then
  mkdir -p "$T/pay/usr/share/sunshine/hyprland"; cp -a "$P/root" "$P/packages.txt" "$T/pay/usr/share/sunshine/hyprland/"
  tar --zstd -C "$T/pay" -cf "$HERE/packages/sunshine-payload/sunshine-payload-src.tar.zst" .
  echo "sunshine-payload source: $(du -h "$HERE/packages/sunshine-payload/sunshine-payload-src.tar.zst" | cut -f1)"
else echo "no Hyprland payload in the checkout (run tools/import-end4.sh); sunshine-payload not staged"; fi

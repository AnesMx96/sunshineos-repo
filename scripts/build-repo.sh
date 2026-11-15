#!/usr/bin/env bash
# Builds the [sunshine] repository: stages the sources from a SunshineOS checkout, builds packages/* in a clean Arch container, adds the
# AUR-built packages the ISO build already made (SunshineOS/repo), and writes the repo database. Result: out/repo/
# usage: scripts/build-repo.sh /path/to/SunshineOS        (needs Docker and the sunshineos-builder image from the SunshineOS build)
set -euo pipefail
SRC=${1:?path to the SunshineOS checkout}
cd "$(dirname "$0")/.."
OUT=$PWD/out/repo; mkdir -p "$OUT"
scripts/gen-lists.sh "$SRC" >/dev/null
scripts/stage-src.sh "$SRC"
chmod -R a+rX packages "$SRC/repo" 2>/dev/null || true
docker run --rm -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" -v "$PWD/packages:/packages:ro" -v "$OUT:/out" -v "$SRC/repo:/aur:ro" \
  sunshineos-builder bash -c '
  set -e
  id builder &>/dev/null || useradd -m builder
  mkdir -p /build && chown builder /build
  for d in /packages/*/; do
    p=$(basename "$d"); [ -f "$d/PKGBUILD" ] || continue
    sudo -u builder bash -c "rm -rf /build/$p && cp -r /packages/$p /build/$p && cd /build/$p && makepkg -df --noconfirm >/tmp/build-$p.log 2>&1" \
      || { echo "FAILED: $p"; tail -20 /tmp/build-$p.log; exit 1; }
    rm -f /out/$p-[0-9]*.pkg.tar.zst; cp /build/$p/*.pkg.tar.zst /out/   # as root: the builder user cannot write to a host-owned directory
    echo "built $p"
  done
  # packages that are only in the AUR: built once by the ISO build, published here so a plain Arch machine does not need the AUR
  for f in /aur/*.pkg.tar.zst; do case "$f" in *-debug-*|*/calamares-*) continue;; esac; cp -f "$f" /out/; done
  # a package must never change the mode of a system directory: repack the ones that ship /usr, /etc, /opt, /var with another mode than 755
  for f in /out/*.pkg.tar.zst; do
    if bsdtar -tvf "$f" | awk "\$9 ~ /^(usr|etc|opt|var|usr\/(bin|lib|share)|var\/lib)\/?\$/ && \$1 !~ /^d.{2}x.{2}x.{2}x/ {f=1} END{exit !f}"; then
      echo "fixing directory modes in $(basename "$f")"; t=$(mktemp -d); bsdtar -xpf "$f" -C "$t"
      for d in usr etc opt var usr/bin usr/lib usr/share var/lib; do [ -d "$t/$d" ] && chmod 755 "$t/$d"; done
      (cd "$t" && bsdtar --zstd -cf "$f.new" .PKGINFO $(ls -A | grep -v "^.PKGINFO$")) && mv "$f.new" "$f"; rm -rf "$t"
    fi
  done
  cd /out && rm -f sunshine.db* sunshine.files* && repo-add -q sunshine.db.tar.gz ./*.pkg.tar.zst
  chown -R "$HOST_UID:$HOST_GID" /out'
ls -la "$OUT" | awk '{print $5, $9}' | tail -n +4

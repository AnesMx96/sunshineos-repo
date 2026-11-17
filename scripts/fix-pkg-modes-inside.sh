#!/usr/bin/env bash
# Runs INSIDE the build container. Every file of a package must be readable by normal users and no package may change the mode of a system
# directory (/usr, /etc, ...): a build on a host with restrictive default ACLs makes files root-only (then the Darkly style, GTK themes, `uni`,
# the browser exist but only root can read them). Packages with such entries are repacked with "other" read (and execute where the owner has it).
# usage: fix-pkg-modes-inside.sh <dir with *.pkg.tar.zst>
set -e
cd "${1:?dir}"; out=$(pwd)
for f in *.pkg.tar.zst; do
  case "$f" in *-debug-*) continue;; esac
  n=$(bsdtar -tvf "$f" | awk 'substr($1,1,1)!="l" && substr($1,8,1)!="r" && $9 !~ /^\.(PKGINFO|BUILDINFO|MTREE)$/ {c++} END{print c+0}')
  top=$(bsdtar -tvf "$f" | awk '$9 ~ /^(usr|etc|opt|var|usr\/(bin|lib|share)|var\/lib)\/?$/ && $1 !~ /^d.{2}x.{2}x.{2}x/ {c++} END{print c+0}')
  [ "$n" -gt 0 ] || [ "$top" -gt 0 ] || continue
  echo "fixing modes in $f ($n files, $top system dirs)"
  t=$(mktemp -d); bsdtar -xpf "$f" -C "$t"
  (cd "$t" && find . -mindepth 1 -not -path "./.*" -not -type l -exec chmod go+rX {} +)
  for d in usr etc opt var usr/bin usr/lib usr/share var/lib; do [ -d "$t/$d" ] && chmod 755 "$t/$d"; done
  rm -f "$t/.MTREE"
  (cd "$t" && bsdtar --zstd -cf "$out/$f.new" .PKGINFO $(ls -A | grep -v '^\.PKGINFO$')) && mv -f "$out/$f.new" "$out/$f"
  rm -rf "$t"
done

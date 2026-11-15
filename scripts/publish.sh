#!/usr/bin/env bash
# Uploads out/repo/ to the `repo` release of this repository (the pacman Server URL points at it). Replaces the old files, because the
# database must always match the package files that are there.     usage: scripts/publish.sh
set -euo pipefail
cd "$(dirname "$0")/.."
REPO=${GH_REPO:-tak0dan/sunshineos-repo}; TAG=repo
[ -f out/repo/sunshine.db.tar.gz ] || { echo "run scripts/build-repo.sh first"; exit 1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cp out/repo/*.pkg.tar.zst "$T/"
# GitHub release assets cannot be symlinks: pacman asks for sunshine.db / sunshine.files, so they are real copies
cp out/repo/sunshine.db.tar.gz "$T/sunshine.db"; cp out/repo/sunshine.db.tar.gz "$T/sunshine.db.tar.gz"
cp out/repo/sunshine.files.tar.gz "$T/sunshine.files"; cp out/repo/sunshine.files.tar.gz "$T/sunshine.files.tar.gz"
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release view "$TAG" --repo "$REPO" --json assets --jq '.assets[].name' | while read -r a; do gh release delete-asset "$TAG" "$a" --repo "$REPO" -y; done
else
  gh release create "$TAG" --repo "$REPO" --title "pacman repository" --notes "The [sunshine] pacman repository (see the README). Files here are replaced on every publish." --latest=false
fi
gh release upload "$TAG" "$T"/* --repo "$REPO" --clobber
echo "published: https://github.com/$REPO/releases/tag/$TAG"

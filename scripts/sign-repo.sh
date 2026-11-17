#!/usr/bin/env bash
# Signs the packages and the database in out/repo/ with the repository key (kept outside every checkout: ~/sunshineos-build/signing,
# or $SUNSHINE_SIGNING_HOME). The public key ships in the keyring files of sunshine-base and the ISO. usage: scripts/sign-repo.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GH=${SUNSHINE_SIGNING_HOME:-$HOME/sunshineos-build/signing}; KEY=$(cat "$GH/key-fingerprint"); export GNUPGHOME=$GH
cd out/repo
rm -f ./*.sig
for p in ./*.pkg.tar.zst; do gpg --homedir "$GH" --batch --yes --detach-sign --no-armor --local-user "$KEY" -o "$p.sig" "$p"; done
rm -f sunshine.db* sunshine.files*
repo-add --sign --key "$KEY" -q sunshine.db.tar.gz ./*.pkg.tar.zst 2>&1 | grep -v "^gpg: " || true
ls ./*.sig | wc -l | xargs echo "signed files:"; ls sunshine.db.tar.gz.sig >/dev/null && echo "database signed"

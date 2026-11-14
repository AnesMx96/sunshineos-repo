# TODO

Order matters: each stage works on its own and is tested in a throwaway Arch container / VM before the next.

## 0. Decisions still open
- [ ] **Signing.** Start unsigned (`SigLevel = Optional TrustAll`), then create a repo key, publish it, and switch to `Required`.
      Until then the repo must not be advertised as safe for machines that matter.
- [ ] **Hosting limits.** GitHub release assets are limited to 2 GiB per file and the repo as a whole is not meant as a CDN.
      Check the total size of the package set; large packages (quickshell, ...) may need a second mirror.
- [ ] **Package set.** Which packages are "Sunshine" (Plasma + Hyprland payload + tools) and which are optional.
- [ ] **Kernel.** Keep the user's kernel (default) or replace it? Default: keep.

## 1. Repository
- [ ] `scripts/build-repo.sh`: build every PKGBUILD in `packages/` in a clean container, `repo-add` into `sunshine.db`.
- [ ] `scripts/publish.sh`: upload `*.pkg.tar.zst`, `sunshine.db`, `sunshine.files` to the `repo` release, replacing old versions
      (the db must always match the files that are there).
- [ ] Test: a fresh `archlinux` container with only pacman can `pacman -Sy` and install a package from the repo.
- [ ] Move the packages the ISO build already makes (`uni-pkg-git`, `sunshine-store`, `librepods`, ...) into this repo.

## 2. `sunshine-base` meta-package
- [ ] `package-list/`: one list, read by the ISO build (`profile/packages.x86_64`) and by `sunshine-base` (`depends`).
- [ ] Ship configs, hooks (`90-sunshine-nixos-grub.hook`, identity restore), scripts (`/usr/local/bin/sunshine-*` -> `/usr/bin`),
      os-release/issue/branding, default skel, service presets.
- [ ] Anything that must not overwrite a user's file goes through `backup=()` or is applied by the doctor only when absent.
- [ ] Decide what `sunshine-base` conflicts with (display manager choice, shells).

## 2b. Payload (Hyprland / end-4 dots and their packages)
- [ ] Today the ISO build makes the payload with `tools/import-end4.sh` (dots, offline package repo) and `tools/build-venv.sh`
      (Python venv). Turn it into packages in this repo (`sunshine-hyprland`, `sunshine-hyprland-venv`) so an Arch machine
      gets it with `pacman -S`, no ISO needed.
- [ ] The payload must be deployable per user on an existing system: dots go to `/usr/share/sunshine/hyprland`, a user's
      `~/.config` is only changed by `sunshine-hyprland-install` and only for files the user has not modified (backup first).
- [ ] Pin the payload's AUR-only dependencies (quickshell, microtex, bibata, icon font, ...) as built packages in the repo,
      so conversion never depends on the AUR being reachable or on a dependency that was removed there.
- [ ] Payload version recorded in `/usr/share/sunshine/payload-version`; the doctor compares it with the repo's.

## 3. Converging doctor (`sunshine-doctor --fix`)
- [ ] Rewrite as a list of **checks with fixes** (data, not a long script): `check_x` returns ok/bad, `fix_x` is idempotent.
- [ ] Exit codes: 0 everything true, 1 something was fixed (run again), 2 something cannot be fixed automatically.
- [ ] Pass 1 (pacman works): stale `db.lck`, keyring (`pacman-key --init/--populate`), mirrorlist, partial upgrade (`pacman -Syu`),
      broken db (`pacman -Dk`), missing `/var/lib/pacman/sync`.
- [ ] Pass 2: write the `[sunshine]` section idempotently, import and sign the repo key.
- [ ] Pass 3-5 as in the README table; `--convert` gate for bootloader/initramfs/os-release.
- [ ] `--dry-run` prints the plan; `--loop` repeats until exit 0 or no progress (guard against endless loops: stop when two
      passes in a row fix the same thing).
- [ ] A standalone bootstrap one-liner for a machine that has no doctor yet:
      `curl -fsSL .../bootstrap.sh | sudo sh` (adds the repo, installs `sunshine-base`, runs the doctor). Needs only pacman + curl.
- [ ] Update `sunshine-update` (system update tool) to run the doctor and pull missing assets after `pacman -Syu`.

## 3b. System upgrade on the repos
- [ ] `sunshine-update` = one command: (1) doctor pass 1 (pacman healthy), (2) `pacman -Syu` including `[sunshine]`
      (so `sunshine-base`, the payload and the store update together with Arch), (3) other sources through UNI: AUR, Flatpak,
      AppImage, Nix profile, (4) pull missing assets from the assets repo, (5) post-upgrade hooks: identity restore, initramfs/GRUB
      (+ NixOS entry), snapshot before and after.
- [ ] Partial-upgrade protection: refuse `pacman -Sy <pkg>` style installs from the store/UNI; always `-Syu`.
- [ ] Order guarantee: `[sunshine]` packages are built against the current Arch repos; the release job rebuilds them when
      Arch bumps a library they link to (soname bumps), and the doctor reports "repo behind Arch" instead of upgrading into a
      broken state.
- [ ] Rollback: snapper snapshot pre-upgrade, `sunshine-update --rollback`.
- [ ] Declarative layer: `/etc/sunshine/system.toml` (services, Nix-managed packages); the update applies it after the upgrade.

## 4. Test matrix
- [ ] Container: stock Arch -> loop `--fix` -> becomes Sunshine (identity, packages, services present).
- [ ] Container: broken Arch (stale lock, empty keyring, no mirrorlist, half-upgraded) -> converges.
- [ ] VM: real Arch install (UEFI and BIOS) -> `--convert` -> reboot -> Plasma/Hyprland session starts (use `test/smoke.sh`).
- [ ] Upgrade: an old converged image + new repo state -> `sunshine-update` -> everything still boots and passes the smoke test.
- [ ] Idempotence: running the doctor on a finished system changes nothing and exits 0.
- [ ] Derivatives: Garuda/EndeavourOS/Manjaro detected and refused or handled explicitly (their repos conflict with ours).

## 5. Docs
- [ ] Install page on the project website ("Already on Arch?").
- [ ] What is changed on the machine, how to undo it (`--convert` creates a snapshot first when snapper/btrfs is present).

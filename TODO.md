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

## 4. Test matrix
- [ ] Container: stock Arch -> loop `--fix` -> becomes Sunshine (identity, packages, services present).
- [ ] Container: broken Arch (stale lock, empty keyring, no mirrorlist, half-upgraded) -> converges.
- [ ] VM: real Arch install (UEFI and BIOS) -> `--convert` -> reboot -> Plasma/Hyprland session starts (use `test/smoke.sh`).
- [ ] Idempotence: running the doctor on a finished system changes nothing and exits 0.
- [ ] Derivatives: Garuda/EndeavourOS/Manjaro detected and refused or handled explicitly (their repos conflict with ours).

## 5. Docs
- [ ] Install page on the project website ("Already on Arch?").
- [ ] What is changed on the machine, how to undo it (`--convert` creates a snapshot first when snapper/btrfs is present).

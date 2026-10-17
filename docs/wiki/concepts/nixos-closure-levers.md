# Concept: NixOS closure size levers

**Status:** current · Sources: `nixpkgs-corepackages-toplevel`, `siraben-smallest-iso`,
`natkr-nixos-but-smol`, `rafael-minimal-closure`, `nixpkgs-minimal-profiles`.

What actually costs bytes in a NixOS system closure, and the ordered levers to
cut them.

## Dominant contributors (x86_64-linux)

| Component | Size | Source |
|---|---|---|
| full systemd | ≈166 MiB (slim ≈35) | `rafael-minimal-closure` / `siraben-smallest-iso` |
| stock kernel modules | ≈144 MiB | `natkr-nixos-but-smol` |
| kernel bzImage (default zstd) | ≈13 MiB (XZ smaller) | `natkr-nixos-but-smol` |
| glibc | ≈35 MiB | `siraben-smallest-iso` |
| perl (activation only) | ≈56 MiB | `natkr-nixos-but-smol` |
| boost (via nix-util, if Nix present) | ≈15 MiB | `natkr-nixos-but-smol` |
| python3 (e.g. per-context) | ≈128 MiB | `natkr-nixos-but-smol` |
| C++ stdlib (switch-to-configuration) | ≈10 MiB | `siraben-smallest-iso` |
| `linux-headers-static` (suid wrappers) | ≈7 MiB | `siraben-smallest-iso` |
| udev `hwdb.bin` | ≈13 MiB | `siraben-smallest-iso` |

Baseline: `system.includeBuildDependencies = true` balloons a minimal config from
**~670 MiB to 13.5 GiB** — keep it `false` (default).

## Measurement (do this first)

- `nix-store --optimise` → dedupe hard links; reports freed bytes.
- `nix-collect-garbage -d` → delete old generations + unreachable paths.
- `nix path-info -Sh /run/current-system` → current system closure size.
- `nix why-depends <closure-root> <store-path> --precise` → *why* a package is
  pulled in (root = `config.isoImage.storeContents` for an ISO) (`natkr-nixos-but-smol`).
- `journalctl --disk-usage` → journal size (separate from store).
- `du` on a mounted `nix-store.squashfs` to rank packages by uncompressed size.

## Ordered levers (biggest first, for a server — not a live ISO)

1. **Generations / GC** — often the largest cut; see `nix-store-disk-control`.
2. **Empty `environment.defaultPackages`** — removes perl, rsync, strace
   (`minimal.nix` already does this; confirm not overridden).
3. **`environment.corePackages`** — default = core list ++ `stdenv.cc.libc`;
   trim tools that exist only to sit in `$PATH` (careful: activation-referenced
   tools stay by store path regardless).
4. **Slim systemd via a package overlay** — a `systemd.package` swap alone leaves
   a second full systemd pulled by libsystemd consumers; use an overlay
   (`siraben-smallest-iso`). Cuts ~130 MiB.
5. **Drop runtime kernel modules** — `system.systemBuilderCommands = mkAfter "rm $out/kernel-modules"`
   removes runtime module loading entirely (`natkr-nixos-but-smol`). Hostile to
   hardware changes; load needed modules via initrd instead.
6. **Firmware** — `hardware.enableRedistributableFirmware = false` (`nixpkgs-corepackages-toplevel`).
7. **Perl removal** — `system.etc.overlay.enable` + `services.userborn.enable`
   (the `perlless` profile).
8. **XZ-compress kernel** — `KERNEL_XZ = yes`, `KERNEL_ZSTD = no` (`siraben-smallest-iso`).
9. **`documentation.enable = false`** (minimal already sets it).
10. **Locales** — C.UTF-8 needs no locale archive; `i18n.extraLocales = []`.

> CONTRADICTION: `rafael-minimal-closure` reports a minimal closure ≈467.7 MiB
> with systemd ≈166 MiB, whereas `natkr-nixos-but-smol`/`siraben-smallest-iso`
> treat a *slim* systemd as ~35 MiB. These are different builds — rafael measures
> stock systemd, siraben measures a `withXxx=false` overlay. Both can be true;
> do not compare across measurement contexts.

## Caveat

Live-ISO levers (`nix.enable = false`, `system.switch.enable = false`,
`system.extraDependencies = []`) are **image** levers. On a host that is rebuilt
in place, applying them removes the ability to `nixos-rebuild` — see
`profile-based-slimming` and ADR-0000 (this repo: update independence is a hard
invariant).

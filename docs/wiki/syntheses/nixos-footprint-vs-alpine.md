# Synthesis: NixOS footprint vs Alpine — ranked levers

**Status:** current · Sources: all under `sources/`. Assembled 2026-10-16.

Answers: *how much can a NixOS host (1 GB RAM / 10 GB disk) be shrunk, what is
irreducible, and what to do first on `pricklepants`.*

## Headline

- NixOS cannot reach Alpine. Alpine's container base is **≤ 8 MB** and a disk
  install **~130 MB** (`alpine-linux`). NixOS's *irreducible* x86_64-linux floor
  — glibc (35) + slim systemd (35) + kernel bzImage+initrd (~32) — already
  exceeds a full Alpine install (`siraben-smallest-iso`).
- Realistic NixOS outcomes: stock minimal closure **~670 MiB** base reference
  (`nixpkgs-corepackages-toplevel`); minimal appliance closure **~467 MiB**
  (`rafael-minimal-closure`); best-effort live ISO **91 MiB** (`siraben-smallest-iso`);
  tiny appliance **raw image 1.5 GB → 362 MB** (`nixcademy-minimizing-images`).
- "Alpine-like" for NixOS = ~90–500 MiB, not 8 MB. The difference is architectural
  (musl+BusyBox+OpenRC vs glibc+GNU+systemd+bash).

## Ranked levers (host, not live ISO — respects ADR-0000: still rebuildable)

| # | Lever | Typical win | Source | Rebuildable? |
|---|---|---|---|---|
| 1 | Cap generations + regular GC (`nix.gc`, `configurationLimit`) | 0.5–1.5 GB freed | `discourse-nix-store-bloat`, `nixpkgs-corepackages-toplevel` | yes |
| 2 | `auto-optimise-store` + `min-free`/`max-free` | dedupe + survive builds | `natkr-nixos-but-smol`, `nixpkgs-corepackages-toplevel` | yes |
| 3 | Empty `environment.defaultPackages` (perl/rsync/strace) | ~56 MiB (perl) | `natkr-nixos-but-smol`, `nixpkgs-corepackages-toplevel` | yes |
| 4 | `documentation.enable = false` (minimal does it) | tens of MiB | `nixpkgs-minimal-profiles` | yes |
| 5 | Bound journal (`SystemMaxUse`) | ~100 MB | `natkr-nixos-but-smol` | yes |
| 6 | `hardware.enableRedistributableFirmware = false` | firmware blobs | `nixpkgs-corepackages-toplevel` | yes |
| 7 | `perlless` profile (`etc.overlay`+`userborn`) | perl out of activation | `nixpkgs-minimal-profiles` | yes (experimental) |
| 8 | Slim systemd via **overlay** | ~130 MiB | `siraben-smallest-iso` | yes (advanced) |
| 9 | XZ kernel; drop kernel modules | ~10–144 MiB | `siraben-smallest-iso`, `natkr-nixos-but-smol` | partly (modules: hostile) |
| 10 | `nix.enable=false`/`system.switch.enable=false` | Nix+boost+stdlib | `siraben-smallest-iso`, `nixcademy-minimizing-images` | **no** — breaks rebuilds |

## Irreducible floor

glibc ≈35 MiB, slim systemd ≈35 MiB, kernel ≈32 MiB (bzImage+initrd) — ≈100 MiB
before any userland (`siraben-smallest-iso`). Further cuts need a custom minimal
kernel config (high risk) or replacing glibc (out of scope). Suid wrappers
(`unix_chkpwd`) and `linux-headers-static` ≈7 MiB cannot be removed without
breaking login.

## Top 3 for `pricklepants` (already-applied levers noted)

The host already has: zram, hourly `nix.gc -d`, `min-free`/`max-free` 2/3 GiB,
`configurationLimit = 2`, `minimal`+`headless` profiles, journal
`SystemMaxUse=200M`, `auto-optimise-store` (repo `update.nix`), and — because
`minimal` sets them — empty `environment.defaultPackages` and
`hardware.enableRedistributableFirmware = false`. So levers #3 and #6 above are
**already in effect**; nothing to gain there.

Remaining highest-value, verified 2026-10-16 by building the host toplevel:

1. **Slim systemd via overlay** — the single largest achievable closure cut
   (~130 MiB) that does not break `nixos-rebuild`, but requires an overlay, not
   just `systemd.package`, plus matching `systemd.*` module disables
   (`siraben-smallest-iso`). Not yet applied.
2. **`perlless` profile — currently BLOCKED by `git`.** `git`'s runtime closure
   pulls the full perl stack (~51 paths), so `perlless`'s
   `forbiddenDependenciesRegexes = ["perl"]` assertion fails at build time (the
   only inbound perl edge found is `git-2.55.0`). `git` is on every host via
   `modules/common/update.nix:31-33`. Unlocks only if `git` is dropped or
   swapped for a perl-free build. See `concepts/profile-based-slimming`.

Do **not** apply `nix.enable = false` / `system.switch.enable = false`: it breaks
in-place rebuilds and conflicts with ADR-0000's update-independence invariant and
the hourly `system.autoUpgrade`.

## Contradictions / open issues

> CONTRADICTION: systemd size — `rafael-minimal-closure` reports ≈166 MiB
> (stock), `siraben-smallest-iso` reports slim systemd ≈35 MiB after a
> `withXxx=false` overlay. Not a real conflict: different builds. Never compare
> across measurement contexts.

> CONTRADICTION: "closure size" units — `rafael-minimal-closure` is titled
> "100k closure size" while quoting ≈467.7 MiB. Ambiguous whether the headline
> is entry count or bytes. Treat MiB as the usable figure.

- Open: `natkr-nixos-but-smol` notes both `systemdMinimal` and `systemd` are
  bundled in the default closure (unresolved "homework"); siraben resolves it by
  pointing dbus at the slim systemd. Not verified in this repo's nixpkgs.
- Open: impermanence / volatile-root is a known NixOS approach but no source
  page is filed; treat as a candidate research item (`nix-store-disk-control`).

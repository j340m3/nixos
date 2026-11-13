# ADR-0019: Slinky migrates to nixos-uconsole, dropping oom-hardware

**Date**: 2026-11-13
**Status**: accepted
**Deciders**: jeromeb
**Knowledge**: docs/wiki/syntheses/artifact-first-updates.md,
docs/wiki/concepts/hardware-edge-stack.md

## Context

slinky (ClockworkPi uConsole, CM4 / Raspberry Pi 4, aarch64) was built on the
user's own fork of oom-hardware (`github:j340m3/oom-hardware`) plus the
nixos-hardware Raspberry Pi 4 base, a hand-wired `hardware.raspberry-pi."4"`
config.txt/overlays/device-tree block, and a locally built vendor kernel
(`linux_rpi4`, held together by a `callPackage` against
nixos-hardware's `kernel.nix` because nixpkgs had dropped the package).

That stack had three compounding problems:

- **Dead cache**: the community uConsole binary cache
  `cache-nix.project2.xyz` stopped resolving entirely (verified 2026-11-13,
  DNS gone from every vantage; no successor exists — commit `87697ce`
  removes it). Even while alive it never carried slinky's kernel: it
  published a different kernel than slinky's oom-hardware `linux_rpi4`.
- **Unmaintained fork**: oom-hardware upstream is inactive; the fork carries
  the whole uConsole kernel patch set on its own, against a nixpkgs that no
  longer ships the kernel package it patches.
- **IFD wall**: slinky's toplevel evaluation hit the oom-hardware
  `dtbs-filtered` import-from-derivation, so it could not be evaluated at
  all on the x86_64 dev machine — `just check` skipped it and verification
  was limited to targeted option evals (docs/wiki/index.md convention,
  now removed).

Meanwhile the community `nixos-uconsole` repo
(`github:nixos-uconsole/nixos-uconsole`, MIT) actively maintains the full
uConsole stack — kernel patches, config.txt generation, panel/power
drivers, sleep and 4G modules — on top of `nvmd/nixos-raspberrypi`, which
generates config.txt without device-tree IFD.

## Decision

1. **Adopt nixos-uconsole v1.1.1** (`nixosModules.uconsole-cm4` all-in-one:
   kernel + configtxt + cm + base + uc-sleep + uc-4g) on top of
   **nvmd/nixos-raspberrypi v1.20260317.0**, both inputs declared in
   `modules/nix/inputs.nix` **following the fleet's nixpkgs pin**
   (nixos-unstable), and nixos-uconsole's nixos-raspberrypi following the
   same input (dedupe). Upstream pins nixos-25.11; we deliberately do not —
   keeping one fleet nixpkgs (ADR-0012 neglect tolerance: one bump lands
   everywhere at once). Consequence: their cachix
   (`nixos-clockworkpi-uconsole.cachix.org`, injected by their base module)
   never serves us — left in, inert.
2. **Drop the oom-hardware input entirely** (slinky was its only consumer).
   Also drop the nixos-hardware rpi4 imports on slinky (nixos-hardware stays
   as a fleet input for lenny/zurg).
3. **Replicate the nvmd factory wiring** inside slinky's flake-parts
   nixosConfiguration (their `lib.nixosSystem` is not used):
   `_module.args.nixos-raspberrypi`, `lib.inject-overlays`,
   `nixosModules.nixpkgs-rpi` (pkgs.rpi scope),
   `nixosModules.raspberry-pi-4.base` + `.bluetooth`, plus the two
   compatibility fixes upstream applies but does not export as modules
   (`disabledModules = [ rename.nix ]`, `checkConfigurationOptions` alias)
   and `boot.loader.raspberry-pi.bootloader = "kernel"`.
4. **In-place bootloader switch**: extlinux/u-boot → nvmd's generational
   kernel boot (config.txt boots the generation's kernel directly,
   `os_prefix=nixos/default/`). Partition layout is unchanged (`/` ext4
   UUID 4444…8888, `/boot/firmware` vfat UUID 2178-694E) — no re-flash.
   Recovery fallback: SD-card access.
5. **Preserve slinky's proven hardware divergence from uconsole defaults**,
   via `hardware.raspberry-pi.config.cm4`: `otg_mode.enable = false` +
   `dwc2.dr_mode = "host"` (the `nopcie0` overlay param kills XHCI/VL805,
   so USB must come from dwc2 — upstream defaults assume XHCI host),
   `spi = off`, `i2c_arm = on`, `cpu-revision cm4-8`. HDMI1 is *enabled*
   (upstream default `nohdmi1 = off`) where slinky previously disabled it —
   kept upstream, revisit on first boot.
6. **linux-kernel platform shim**: nvmd v1.20260317.0 reads
   `stdenv.hostPlatform.linux-kernel.target`, an attribute nixpkgs 26.11
   removed. Bumping nvmd to the fixed release would drag 8 months of
   vendor-kernel drift under uconsole v1.1.1's patch set, so instead
   `nixpkgs.hostPlatform` is elaborated with
   `linux-kernel = { target = "Image"; }` (single canonical platform shape,
   cross-eval equality intact). Drop the shim when uconsole moves to an
   nvmd release that branches on `lib.trivial.release` (nvmd main does).

Verified: slinky's toplevel now evaluates on x86_64 (the IFD wall is gone —
old `dtbs-filtered` IFD no longer exists; nvmd generates config.txt at
build time), config.txt output checked entry-by-entry against the
pre-migration file, kernel is 6.12.47-stable_20250916 with all 7 uconsole
patches.

## Alternatives Considered

### Alternative 1: Bump nvmd to v1.20261108.0 (native nixpkgs 26.11 support)
- **Pros**: no platform shim needed.
- **Cons**: 8 months of vendor-kernel drift under uconsole v1.1.1's 7
  patches; uconsole has not validated that pairing.
- **Why not**: breaks the kernel patch set to save a 3-line shim.

### Alternative 2: Keep oom-hardware, only fix the dead cache
- **Cons**: fork stays unmaintained against a nixpkgs without
  `linux_rpi4`; the cache never served slinky's kernel anyway.
- **Why not**: fixes nothing structural.

### Alternative 3: Re-flash the SD card with the official uconsole image
- **Cons**: discards the in-place NixOS system, violates the ADR-0000
  spirit of in-place update; unnecessary — disk layout is compatible.
- **Why not**: migration needs no re-flash.

## Consequences

### Positive
- slinky rides an actively maintained upstream stack; community fixes
  (panel, power, sleep) arrive as input bumps, not fork chores.
- Full toplevel eval on x86_64 — slinky can rejoin the CI gate (`just check`
  still skips it by system mismatch; no IFD excuse anymore).
- Kernel cacheability via ADR-0018: the artifact publisher builds slinky's
  toplevel into woody's store, which is the harmonia cache — and the
  vendor-kernel patch application target is now pinned (nvmd
  v1.20260317.0) rather than drifting with nixos-hardware.
- One fewer flake input (oom-hardware removed).

### Negative
- Every fleet nixpkgs bump rebuilds the vendor kernel from source
  (binfmt-emulated on woody or a fleet builder; hours) before slinky can
  switch — the price of following unstable instead of upstream's 25.11 pin.
- The kernel build is now 6.12.47 (nvmd vendor kernel) instead of 6.6.51:
  first boot after migration changes the major kernel version at the same
  time as the bootloader.
- uconsole's base module defaults (root password flow, console font,
  cachix substituter) need the `mkForce` neutralizations kept in
  slinky/configuration.nix — a small upstream-coupling surface to re-check
  on uconsole bumps.

### Risks
- **Bootloader switch is the riskiest step**: a bad config.txt/boot.scr on
  the generation boundary can brick boot. Mitigation: SD access for
  recovery; the old extlinux generations stay on disk.
- Patch-set drift: if nvmd bumps its vendor kernel before uconsole revalids
  its patches, a routine `nix flake lock --update` can break the kernel
  build. Bump nvmd and nixos-uconsole together, never alone.
- The `linux-kernel` shim is dormant-assert territory (it survives only
  because the pin's `oldestSupportedRelease` makes nvmd's assert
  unreachable); the removal condition is documented in the config comment.

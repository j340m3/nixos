---
title: nixpkgs closure size, core packages, /etc overlay, oomd, zram, nix.gc
url: file:///nix/store/r5l65vg4gi4dnx54zkwagfb8jmlqniy5-source/nixos/modules/
kind: primary
accessed: 2026-10-16
---

# nixpkgs internals affecting footprint (26.11pre-git)

Local nixpkgs checkout. Authoritative for option names/defaults cited in concepts.

## Closure size — `system/activation/top-level.nix`

- `system.includeBuildDependencies` (default `false`): builds the *build* closure
  into the runtime closure. Doc text: a minimal config "grows from **~670MiB in size
  to 13.5GiB**" when enabled. Keep it `false`.

## Default packages — `config/system-path.nix`

- `environment.corePackages` = `corePackageNames` **++ `[ pkgs.stdenv.cc.libc ]`**.
- `environment.defaultPackages` default = `[ "perl" "rsync" "strace" ]`.
- `minimal.nix` empties `defaultPackages`; that is what removes perl/rsync/strace.

## Removed option

- `environment.noXlibs` is **removed** (in `rename.nix`); `nixpkgs` minimal no
  longer sets it. Do not look for it.

## Locale

- `i18n.supportedLocales` is deprecated in favour of `i18n.extraLocales`
  (`config/i18n.nix`). C.UTF-8 is built into glibc → no locale archive needed.

## `/etc` overlay — `system/etc/etc.nix`, `etc-activation.nix`

- `system.etc.overlay.enable` mounts `/etc` as overlayfs instead of the perl
  script. Requires `boot.initrd.systemd.enable`.
- `system.etc.overlay.mutable = false` requires `systemd.sysusers.enable` or
  `services.userborn.enable`; also needs kernel ≥ 6.6 for switchable systems.
- With overlay + userborn, perl is no longer needed for activation.

## userborn — `services/system/userborn.nix`

- `services.userborn.enable` implements user/group management natively (replaces perl).

## switch-to-configuration — `system/activation/switchable-system.nix`

- `system.switch.enable` default `true`; set `false` on immutable images to drop
  `switch-to-configuration` (and its C++ stdlib). Used by `image-based-appliance`.

## OOM handling — `system/boot/systemd/oomd.nix`

- `systemd.oomd.enable` default **true**. `enableRootSlice`/`enableSystemSlice`/
  `enableUserSlices` control which slices get `ManagedOOMMemoryPressure=kill`
  (`ManagedOOMMemoryPressureLimit` default 80%). `systemd.oomd.settings.OOM`
  is freeform → `oomd.conf(5)`.
- Alternative/additional: `earlyoom` module (used by this repo's `commonMem`).

## zram — `config/zram.nix`

- `zramSwap.enable` default false; `memoryPercent` default 50; `algorithm` default
  `zstd`; `priority` default 5; `swapDevices` default 1.

## GC — `services/misc/nix-gc.nix`

- `nix.gc.automatic`, `.dates`, `.randomizedDelaySec`, `.persistent`, `.options`
  (passed to `nix-collect-garbage`). Assertion: `nix.gc.automatic` requires `nix.enable`.
  Service `startAt = cfg.dates`; timer sets `RandomizedDelaySec`/`Persistent`.

## Firmware — `hardware/all-firmware.nix`

- `hardware.enableAllFirmware`; `hardware.enableRedistributableFirmware`
  (defaults to `enableAllFirmware`). Disable to shed firmware blobs.

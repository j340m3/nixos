# Concept: RAM footprint (1 GB hosts)

**Status:** current · Sources: `nixpkgs-corepackages-toplevel`, `natkr-nixos-but-smol`.

Minimising RAM *pressure* on a 1 GB host — distinct from closure/disk size.
The repo's `commonMem` module already implements most of this; this page records
the nixpkgs-level facts behind it.

## Compression swap

- `zramSwap.enable = true` (`config/zram.nix`): compressed RAM swap. Defaults:
  `memoryPercent = 50`, `algorithm = "zstd"`, `priority = 5`, `swapDevices = 1`.
- Tuning sysctls for zram-only swap (community): `vm.swappiness = 180`,
  `vm.page-cluster = 0`. (Reported practice, not from a filed primary source.)

## OOM handling

- `systemd.oomd.enable` defaults **true** in nixpkgs; `enableRootSlice`/
  `enableSystemSlice`/`enableUserSlices` install `ManagedOOMMemoryPressure=kill`
  at 80% per slice (`system/boot/systemd/oomd.nix`).
- `earlyoom` is an alternative/additional userspace OOM killer; this repo's
  `commonMem` uses earlyoom with per-service prefer/avoid patterns and
  `MemoryMax`/`MemoryHigh` ceilings. (Repo-local; see `modules/common/mem.nix`.)

## Kernel modules vs RAM

Dropping runtime kernel modules (`natkr-nixos-but-smol`) saves disk, and the
corresponding smaller module set costs nothing at runtime if the hardware is
fixed — but you lose the ability to load a module you did not pre-list.

## Build-time RAM

- Builds are the peak RAM consumer on a 1 GB host. The repo's `commonMem` plus
  `nix.settings.cores = 1` / `max-jobs = 1` (`modules/common/update.nix`) bound
  a build to one job — the single most important RAM lever when rebuilding on
  the host. Remote builders (`modules/remote-builder.nix`) offload it entirely
  when a sibling is available (best-effort per ADR-0000).

## Caveat

On a 1 GB host, swap that is *not* zram (encrypted disk swap) trades RAM for
disk I/O; `pricklepants` has it commented out in favour of zram (`default.nix`).

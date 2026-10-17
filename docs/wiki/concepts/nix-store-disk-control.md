# Concept: Nix store disk control

**Status:** current · Sources: `nixpkgs-corepackages-toplevel`,
`discourse-nix-store-bloat`, `discourse-storage-requirements`, `natkr-nixos-but-smol`.

Keeping the store bounded on a small disk (the `pricklepants` case: 10 GB ext4).

## Generations dominate

The store holds *every* generation's closure until garbage collected. Reported:
3.5 GB → 2.0 GB after `nix-collect-garbage -d` (`discourse-nix-store-bloat`); a
user freed 1.5 GiB / 123 paths with `-d` (`natkr-nixos-but-smol` comment). So the
first lever is **generation count + GC cadence**, not packaging.

## Levers

- `nix.gc.automatic = true`; `nix.gc.dates = "hourly"|"daily"`; `nix.gc.options`
  e.g. `"-d"` or `"--delete-older-than 2d"` (options go to `nix-collect-garbage`;
  `services/misc/nix-gc.nix`). Assertion: requires `nix.enable`.
- `boot.loader.grub.configurationLimit = N` (or systemd-boot's) — caps generation
  count; `pricklepants` uses 2.
- `nix.settings.auto-optimise-store = true` — dedupe identical store paths.
  One-off: `nix-store --optimize` (reported result 382.4 MiB).
- `nix.settings.min-free` / `max-free` — the daemon runs GC *during* a build when
  free space drops below `min-free`, freeing until `max-free`. Critical on a
  10 GB disk where a rebuild needs the new closure beside the old (`nix.conf`
  settings). `pricklepants` forces 2 GiB / 3 GiB.
- `boot.tmp.cleanOnBoot = true` — clears `/tmp` (separate from store).
- Journal: `services.journald.settings.Journal.SystemMaxUse` (+ `SystemMaxFileSize`)
  bounds journal size. Reported default usage 145.6 MB on a small VPS.
- `nix.gc.automatic` + `randomizedDelaySec` avoids thundering-herd GCs across hosts.

## Note on disk budget

Nix rebuilds are copy-on-write: budget room for **two closures** plus GC
headroom (`discourse-storage-requirements`). `max-free`/`min-free` is the
mechanism that makes this survivable at 10 GB.

## Impermanence (not yet sourced)

Booting with `/` (or `/nix`) on a tmpfs/volatile root and persisting only
declared state is a known NixOS approach, but **not yet filed** in this vault —
no source page. Treat as a candidate research item, not an established lever.

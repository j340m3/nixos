# ADR-0009: Disko bootstrap images incl. impermanence variant

**Date**: 2025-04-11 (disko bootstrap born) + 2026-01-27 (image outputs and
impermanent variant) (backfilled 2026-10-15)
**Status**: accepted (backfilled 2026-10-15)
**Deciders**: j340m3

## Context

New hosts (mostly VPSes) need a reproducible provisioning path. Disk
partitioning and filesystem setup should be declarative, not click-ops in a
provider panel. Several VPSes have under 1 GB of RAM, which rules out
memory-hungry installers — the image must be small enough to write directly
onto the disk. Some hosts want an ephemeral root (impermanence).

## Decision

Define two bootstrap hosts in the flake — `bootstrap` and
`bootstrap-impermanent` — using [disko](https://github.com/nix-community/disko)
for declarative disk layouts. The flake builds them as images via
`packages.x86_64-linux.image[-impermanent]` (through
`config.system.build.diskoImages` plus a small overlay patching
`aggregateModules` for newer nixpkgs). The impermanent variant uses a tmpfs
root with persistence for state.

Provisioning flow: build the image, `dd` it over SSH directly to the target
disk, reboot.

## Alternatives Considered

### Provider-panel installs + manual partitioning
- **Pros**: no tooling.
- **Cons**: not reproducible; drift between hosts; slow to re-provision.
- **Why not**: defeats the point of a declarative repo.

### nixos-anywhere
- **Pros**: well-trodden remote-install flow over SSH.
- **Cons**: needs more RAM than the small (<1 GB) VPSes have — impossible
  there; untried.
- **Why not**: the dd-over-ssh image works on every VPS; nixos-anywhere
  stays an option for the bigger machines.

## Consequences

### Positive
- Re-provisioning a VPS = build image, `dd` over ssh, reboot.
- Impermanence is a first-class variant, not a hand-rolled afterthought.

### Negative
- Image builds carry the disko/nixpkgs compat overlay until upstream fixes
  `aggregateModules`/`kernelModules`.
- Impermanence excludes some features by design (e.g. upgrade-health's
  `/var/lib` guard would not persist — see ADR-0007).

# ADR-0009: Disko bootstrap images incl. impermanence variant

**Date**: ~2025 (backfilled 2026-10-15)
**Status**: accepted
**Deciders**: jeromeb

## Context

New hosts (mostly VPSes) need a reproducible provisioning path. Disk
partitioning and filesystem setup should be declarative, not click-ops in a
provider panel, and some hosts want an ephemeral root (impermanence).

## Decision

Define two bootstrap hosts in the flake — `bootstrap` and
`bootstrap-impermanent` — using [disko](https://github.com/nix-community/disko)
for declarative disk layouts. The flake builds them as images via
`packages.x86_64-linux.image[-impermanent]` (through
`config.system.build.diskoImages` plus a small overlay patching
`aggregateModules` for newer nixpkgs). The impermanent variant uses a tmpfs
root with persistence for state.

## Alternatives Considered

### Provider-panel installs + manual partitioning
- **Pros**: no tooling.
- **Cons**: not reproducible; drift between hosts; slow to re-provision.
- **Why not**: defeats the point of a declarative repo.

### nixos-anywhere
- **Pros**: well-trodden remote-install flow.
- **Cons**: image-based flow already works with disko here.
- **Why not**: revisit if remote install over SSH becomes the common path.

## Consequences

### Positive
- Re-provisioning a VPS = build image, boot it, done.
- Impermanence is a first-class variant, not a hand-rolled afterthought.

### Negative
- Image builds carry the disko/nixpkgs compat overlay until upstream fixes
  `aggregateModules`/`kernelModules`.
- Impermanence excludes some features by design (e.g. upgrade-health's
  `/var/lib` guard would not persist — see ADR-0007).

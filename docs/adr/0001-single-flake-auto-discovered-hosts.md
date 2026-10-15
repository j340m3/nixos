# ADR-0001: Single flake with auto-discovered host folders

**Date**: 2024-12-18
**Status**: accepted (backfilled 2026-10-15)
**Deciders**: jeromeb

## Context

The fleet spans laptops, VPSes, a uConsole, a WSL instance, and bootstrap
images. Each host needs its own NixOS configuration, but hand-listing every
host in `flake.nix` is boilerplate that drifts as hosts are added/retired.

## Decision

One flake holds every host. Each folder under `hosts/graphical/` and
`hosts/headless/` is one `nixosConfiguration`; the flake auto-discovers them
with `builtins.readDir` + `mkHost`. Shared behaviour lives in `modules/`,
per-user config in `users/` and `home/`.

## Alternatives Considered

### Per-host flakes
- **Pros**: full isolation per machine.
- **Cons**: no shared modules without a plumbing flake anyway; lock/update
  churn multiplied by host count.
- **Why not**: one operator, one repo — isolation buys nothing.

### Hand-listed nixosConfigurations
- **Pros**: explicit, greppable.
- **Cons**: every host add touches `flake.nix`; forgettable.
- **Why not**: the auto-discover loop is 5 lines and removes the drift.

## Consequences

### Positive
- Adding a host = create a folder, update `HOSTS.md`. No flake edit.
- One `nix flake update` moves the whole fleet's inputs together.

### Negative
- A stray folder under `hosts/` becomes a configuration; eval checks catch
  breakage, but naming mistakes surface late.

### Risks
- Folder name is the host name — rename = config rename; `HOSTS.md` is the
  human map.

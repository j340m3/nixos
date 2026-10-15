# ADR-0002: flake-parts for perSystem outputs

**Date**: ~2025 (backfilled 2026-10-15)
**Status**: accepted
**Deciders**: jeromeb

## Context

The flake needs both cross-host outputs (`nixosConfigurations`,
`homeConfigurations`) and per-system tooling (devShell, checks, formatter,
bootstrap images). Plain flake `outputs` mixes these and forces manual
`forAllSystems` plumbing.

## Decision

Structure outputs with [flake-parts](https://flake.parts/): host and
home-manager configs live under `flake`, while `packages`/`checks`/
`devShells`/`formatter` live under `perSystem`.

## Alternatives Considered

### Raw flake outputs
- **Pros**: zero dependency.
- **Cons**: repeated `forAllSystems` maps; easy to forget a system.
- **Why not**: flake-parts is the community standard and removes the boilerplate.

### nixos-anywhere / deploy tooling (colmena, deploy-rs)
- **Pros**: richer deploy workflows.
- **Cons**: `nixos-rebuild --flake` + `just rebuild` covers current needs.
- **Why not**: YAGNI; revisit if the fleet outgrows direct rebuilds.

## Consequences

### Positive
- One `systems = [ "x86_64-linux" ]` gates all per-system outputs (aarch64
  hosts still build from `nixosConfigurations`).
- Checks/devShell/formatter defined once, applied uniformly.

### Negative
- One more input; contributors must know the flake-parts convention.

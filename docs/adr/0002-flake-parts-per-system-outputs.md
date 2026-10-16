# ADR-0002: flake-parts for perSystem outputs

**Date**: 2026-10-14
**Status**: accepted (backfilled 2026-10-15)
**Deciders**: j340m3

## Context

The flake needs both cross-host outputs (`nixosConfigurations`,
`homeConfigurations`) and per-system tooling (devShell, checks, formatter,
bootstrap images). flake-parts was first tried on 2026-03-12 bundled with a
larger whole-repo restructure (import-tree module layout): the restructure
looked easy upfront but the details were painful, and it was reverted a
month later ("old config style") for lack of time — the full restructure is
still an open aspiration. The current adoption landed on 2026-10-14 during
a cleanup commit; the exact trigger is fuzzy, plausibly a side-effect of
brainstorming a dendritic repo restructure around that time.

## Decision

Structure outputs with [flake-parts](https://flake.parts/): host and
home-manager configs live under `flake`, while `packages`/`checks`/
`devShells`/`formatter` live under `perSystem`.

## Alternatives Considered

### Raw flake outputs (status quo until 2026-10)
- **Pros**: zero dependency; worked fine for months.
- **Cons**: per-system tooling has to be organized by hand as the output
  set grows (checks, devShell, formatter, images).
- **Why not**: flake-parts is the community standard and gives the
  outputs a uniform shape.

### colmena / deploy-rs
- **Pros**: richer, purpose-built deploy workflows (rollout, activation
  strategy).
- **Cons**: `nixos-rebuild --flake` + `just rebuild` covers current needs.
- **Why not**: YAGNI; revisit if the fleet outgrows direct rebuilds.

## Consequences

### Positive
- One `systems = [ "x86_64-linux" ]` gates all per-system outputs (aarch64
  hosts still build from `nixosConfigurations`).
- Checks/devShell/formatter defined once, applied uniformly.

### Negative
- One more input; contributors must know the flake-parts convention.
- Does not by itself deliver the broader dendritic restructure it rode in
  with — that remains parked.

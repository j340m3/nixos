# ADR-0003: Floating flake.lock + hourly unattended autoUpgrade

**Date**: 2025-04-15
**Status**: accepted (backfilled 2026-10-15)
**Deciders**: jeromeb

## Context

Rolling-release-style delivery: hosts should track nixos-unstable without a
human bumping a lockfile. `system.autoUpgrade` runs hourly and fetches fresh
inputs with `--no-write-lock-file`; `flake.lock` is gitignored so every
upgrade re-resolves against the pinned input refs.

## Decision

Do not commit `flake.lock`. Hosts self-update hourly via `autoUpgrade` on
`switch`. Safety comes from NixOS's atomic activation plus the upgrade-health
rollback (ADR-0007), not from a pinned lock.

## Alternatives Considered

### Committed flake.lock + staged rollout
- **Pros**: reproducibility; breakage surfaces before fleet-wide deploy.
- **Cons**: needs a human or CI gate to bump; trades away "newest state, no
  gate" (noted as a deliberate follow-up in the upgrade-health design).
- **Why not**: chosen as a *future* option, not now — the current model
  optimizes for zero maintenance.

### nixpkgs release branch
- **Pros**: lower upstream breakage rate.
- **Cons**: lags features; still a floating lock within the branch.
- **Why not**: parked as a follow-up alongside locking.

## Consequences

### Positive
- Zero manual nixpkgs bumps across ~10 hosts.
- Every host converges to the same fresh upstream state within the hour.

### Negative
- Broken upstream state can reach every unattended host quickly.
- Builds are not bit-reproducible across time.

### Risks
- Mitigated by ADR-0007 (automatic rollback on failed units) and Telegram
  notifications (`notify-telegram@` template units).

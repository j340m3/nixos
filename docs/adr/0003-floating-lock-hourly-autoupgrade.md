# ADR-0003: Push-to-GitHub delivery with hourly autoUpgrade and floating inputs

**Date**: 2024-12-18 (hourly autoUpgrade from the first commit; floating
`flake.lock` since 2025-04-15)
**Status**: accepted (backfilled 2026-10-15)
**Deciders**: j340m3

## Context

Rolling-release-style delivery: hosts should track nixos-unstable without a
human bumping a lockfile or touching each machine. In practice hosts almost
never get manual `just rebuild` runs — they self-update.

## Decision

Two independent floating levels:

- **Code**: `system.autoUpgrade.flake = "github:j340m3/nixos"` — hosts poll
  the GitHub default branch hourly (`*-*-* 0/1:45:00`, 25min jitter, random
  reboots allowed outside 22:00–08:00). Pushing to GitHub *is* the deploy
  gate for configuration changes.
- **Inputs**: `flake.lock` is gitignored (since 2025-04-15) and autoUpgrade
  passes `--no-write-lock-file`, so every rebuild re-resolves the input refs
  (`nixos-unstable` and friends) fresh. Nothing pins the inputs between
  rebuilds.

Safety comes from NixOS's atomic activation, the upgrade-health rollback
(ADR-0007), and Telegram alerts on failed upgrades — not from a pinned lock.

## Alternatives Considered

### comin (gitops rebuild-on-commit)
- **Pros**: present in the code as `useComin`; rebuilds on pushed commits
  with proper commit-level semantics.
- **Cons**: disabled by default (`useComin = false`); autoUpgrade already
  covers the loop.
- **Why not**: kept as the ready-made alternative if polling ever proves
  insufficient.

### Pin autoUpgrade to `inputs.self.outPath`
- **Pros**: build exactly the flake snapshot deployed on the host.
- **Cons**: an immutable snapshot — never sees new commits and fails forever
  on whatever broke first (documented in the code comment).
- **Why not**: explicitly rejected in `update.nix`.

### Committed flake.lock + staged rollout
- **Pros**: reproducibility; breakage surfaces before fleet-wide deploy.
- **Cons**: needs a human or CI gate to bump; trades away "newest state, no
  gate" (parked as a follow-up in the upgrade-health design).
- **Why not**: the current model optimizes for zero maintenance.

### nixpkgs release branch
- **Pros**: lower upstream breakage rate.
- **Cons**: lags features; still a floating lock within the branch.
- **Why not**: parked as a follow-up alongside locking.

## Consequences

### Positive
- Zero manual nixpkgs bumps across ~10 hosts; push once, fleet converges
  within the hour.
- The lockfile can never conflict, go stale, or block a build.

### Negative
- A broken upstream input resolution or evaluation can reach every
  unattended host quickly (mitigated, not prevented, by ADR-0007).
- Builds are not bit-reproducible over time — only the code state is
  versioned, not the resolved dependency graph.

### Risks
- A bad push deploys fleet-wide within the hour; `nixos-rebuild build`
  before pushing is the only manual gate.

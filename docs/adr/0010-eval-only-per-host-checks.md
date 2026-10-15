# ADR-0010: Eval-only per-host flake checks as the fast CI gate

**Date**: 2026-10 (backfilled 2026-10-15)
**Status**: accepted
**Deciders**: jeromeb

## Context

Building every host on every change is slow and mostly tests nixpkgs, not
this repo. What the repo needs is a fast signal that every host still
*evaluates* — broken imports, bad option values, missing files surface at
eval time.

## Decision

`checks.x86_64-linux.<host>` evaluates each native host by discarding the
toplevel drv string context (`unsafeDiscardStringContext ... drvPath` into a
`runCommand`), without building. `just check` is the local entrypoint; the
same checks run in CI/pre-commit. Foreign-system hosts (aarch64 uConsole)
are filtered out. Behaviour-sensitive modules add small assert-based checks
(e.g. `checks.upgrade-health` asserts service triggers and opt-out).

## Alternatives Considered

### Full `nix flake check` / build all hosts
- **Pros**: catches build-time breakage too.
- **Cons**: very slow (hundreds of inputs re-resolve + builds); noted in the
  secrets design as a daily-dev blocker.
- **Why not**: too slow for the inner loop; build checks can be added
  selectively later.

### No automated checks, rely on `nixos-rebuild` per host
- **Pros**: zero setup.
- **Cons**: breakage found one host at a time, on the host.
- **Why not**: one eval pass covers the fleet in seconds.

## Consequences

### Positive
- Seconds-level feedback that the whole fleet still evaluates.
- Cheap enough to run on every commit via pre-commit/CI.

### Negative
- Eval-only: a package that fails to *build* slips through.
- Assert-style checks (upgrade-health) are bespoke, not a framework.

# ADR-0010: Eval-only per-host flake checks as the fast CI gate

**Date**: 2026-10-14 (backfilled 2026-10-15)
**Status**: accepted (backfilled 2026-10-15)
**Deciders**: j340m3

## Context

Building every host on every change is slow and mostly tests nixpkgs, not
this repo. What the repo needs is a fast signal that every host still
*evaluates* — broken imports, bad option values, missing files surface at
eval time.

## Decision

Evaluate (never build) every native host, two ways that grew together and
have not been unified:

- `checks.x86_64-linux.<host>` — flake checks that discard the toplevel drv
  string context (`unsafeDiscardStringContext ... drvPath` into a
  `runCommand`), so `nix flake check` / `nix build .#checks.x86_64-linux.<h>`
  evaluates without building.
- `just check` — a Justfile bash loop that runs the equivalent `nix eval` per
  host for a quick local signal.

Both filter out foreign-system hosts (the aarch64 uConsole). Behaviour-
sensitive modules add small assert-based checks (e.g. `checks.upgrade-health`
asserts the service triggers and opt-out). Pre-commit hooks run lint only
(deadnix/statix/shellcheck/ruff); there is no hosted CI — the eval gate runs
locally.

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
- Cheap enough to run locally on every change.

### Negative
- Eval-only: a package that fails to *build* slips through.
- Assert-style checks (upgrade-health) are bespoke, not a framework.
- Two separate eval-check implementations (`checks.*` and `just check`) still
  coexist; which one becomes canonical is not settled.

### Open
- Unify the flake checks and `just check` on one implementation.

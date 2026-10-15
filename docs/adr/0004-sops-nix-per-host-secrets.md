# ADR-0004: sops-nix with per-host secrets files

**Date**: 2025-04-15
**Status**: accepted (backfilled 2026-10-15)
**Deciders**: jeromeb

## Context

Hosts need secrets (bot tokens, TLS keys, VPN keys, DB credentials) that
cannot live in a public repo. Distribution must be declarative and fit the
flake rebuild flow.

## Decision

Use [sops-nix](https://github.com/Mic92/sops-nix) with age keys. Secrets live
per host in `secrets/hosts/<host>/secrets.yaml`, service secrets in
`secrets/services/`, with creation rules in `.sops.yaml`. Hosts decrypt at
activation via a host-local `sops.age.keyFile`. Helper scripts in `scripts/`
handle editing, rotation, and host-key publication.

## Alternatives Considered

### agenix
- **Pros**: similar declarative model, simpler CLI.
- **Cons**: sops-nix chosen first; kept as an explicit escape hatch if the
  sops setup proves too fragmented (noted in the identity-architecture design).
- **Why not**: no forcing reason to migrate.

### Single shared secrets.yaml for all hosts
- **Pros**: one file to manage.
- **Cons**: one compromised host key decrypts everything; cross-tenant blast
  radius.
- **Why not**: per-host files deliberately limit blast radius (explicit
  non-goal in identity design §9).

### Imperative secret injection (vault agents, etc.)
- **Pros**: dynamic secrets, revocation.
- **Cons**: runtime dependency on a service; against the "rebuild is deploy"
  model.
- **Why not**: static fleet, no dynamic-secret need.

## Consequences

### Positive
- Secrets rotate by re-encrypting a file and rebuilding; no host shelling.
- `.sops.yaml` rules can scope files to admin-only recipients (see ADR-0008).

### Negative
- New hosts need an age key provisioned before first decrypt.
- Editing secrets requires an admin age key on the operator machine.

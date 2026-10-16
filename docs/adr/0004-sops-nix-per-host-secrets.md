# ADR-0004: sops-nix with per-host secrets files

**Date**: 2025-04-01 (workflow adopted; sops-nix input added 2025-01-15,
current hosts/services/users layout since 2026-02-06)
**Status**: accepted (backfilled 2026-10-15)
**Deciders**: j340m3

## Context

Hosts need secrets (bot tokens, TLS keys, VPN keys, DB credentials) that
cannot live in a public repo. Distribution must be declarative and fit the
flake rebuild flow.

## Decision

Use [sops-nix](https://github.com/Mic92/sops-nix) with age keys. Secrets live
per host in `secrets/hosts/<host>/secrets.yaml`, service secrets in
`secrets/services/`, per-user material in `secrets/users/`, with creation
rules in `.sops.yaml` — each host file's recipients are admin keys plus that
host only, from the very first `.sops.yaml` (2025-04-01). Hosts decrypt at
activation via a host-local `sops.age.keyFile`. Helper scripts in `scripts/`
handle editing, rotation, and host-key publication.

## Alternatives Considered

### agenix
- **Pros**: similar declarative model, simpler single-file CLI.
- **Cons**: sops-nix won the original comparison; agenix remained on the
  table as the documented escape hatch through the 2026-10 identity-architecture
  review ("explicitly rejected for this cycle").
- **Why not**: no forcing reason to migrate — sops-nix handles the file-based,
  multi-recipient layout the repo needs.

### Single shared secrets.yaml for all hosts
- **Pros**: one file to manage.
- **Cons**: one compromised host key decrypts everything; cross-tenant blast
  radius.
- **Why not**: per-host files deliberately limit blast radius (explicit
  non-goal in identity design §9); recipient rules enforce it — a host
  literally cannot decrypt another host's file.

## Consequences

### Positive
- Secrets rotate by re-encrypting a file and rebuilding; no host shelling.
- `.sops.yaml` rules can scope files to admin-only recipients (see ADR-0008).
- Blast radius per host key compromise is bounded to that host's files.

### Negative
- New hosts need an age key provisioned before first decrypt.
- Editing secrets requires an admin age key on the operator machine.
- Per-host files multiply: rotating an age key means re-encrypting each
  affected file (the rotate script's job).

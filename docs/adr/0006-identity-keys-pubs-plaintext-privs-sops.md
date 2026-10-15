# ADR-0006: Identity keys — pubs plaintext, privs in sops

**Date**: 2026-10-05
**Status**: accepted (backfilled 2026-10-15)
**Deciders**: jeromeb

## Context

SSH host keys were auto-generated per host with no declared pubs, so every
`ssh builderN` hit an interactive host-key prompt and key rotation meant
deleting keys on the host. Borg client pubs were hand-typed into server
config and could drift ("borg pubkey missing" bugs). Key material needed a
uniform, declarative home.

## Decision

Split key material by visibility:

- **Identity keys** (host SSH, build identity, borg client): pub committed
  plaintext at `secrets/common/ssh/<host>/<label>.pub` (read at eval via
  `lib.fileContents`); priv encrypted in the host's sops `secrets.yaml`.
- **Secret data** (tokens, TLS keys, certs): stays fully sops-encrypted.

Consumers (`knownHosts`, `authorizedKeys`, borg-server) read pubs from the
committed files, so enrolling a host auto-wires trust everywhere. The shared
`remotebuild` builder identity stays one keypair across hosts (5a over
per-host build identities) to keep rotation simple.

## Alternatives Considered

### Per-host build identities (5b)
- **Pros**: uniform with host keys; smaller blast radius per host.
- **Cons**: more files; rotation touches every host's knownHosts anyway.
- **Why not**: shared key + rotation script is the smaller lift; flagged the
  blast radius in the design.

### Auto-generate host keys only, publish nothing
- **Pros**: zero repo content.
- **Cons**: keeps the `ssh yes` prompt and manual rotation pain — the
  original bug.
- **Why not**: this was the status quo being fixed.

### agenix migration
- **Pros**: alternative secrets tool.
- **Cons**: explicitly rejected for this cycle; sops-nix path was working.
- **Why not**: no forcing function (see ADR-0004).

## Consequences

### Positive
- No interactive host-key prompts; borg pubs cannot drift from server config.
- Identity rotation = regenerate pair, update sops, commit pub, rebuild.

### Negative
- Pubs are public in a public repo (acceptable: they are public by design).
- Shared `remotebuild` key means rotating it touches all hosts (the rotate
  script's job).

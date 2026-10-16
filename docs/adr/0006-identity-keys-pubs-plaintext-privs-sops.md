# ADR-0006: Identity keys — pubs plaintext, privs in sops

**Date**: 2026-10-05 (design accepted; machinery implemented Oct 2026,
fleet-wide enrollment still partial as of backfill 2026-10-15)
**Status**: accepted (backfilled 2026-10-15)
**Deciders**: j340m3

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

Consumers (`knownHosts` in `modules/common/ssh-identities.nix`,
`authorizedKeys`, borg-server) read pubs from the committed files, so
enrolling a host auto-wires trust everywhere. The build identity stays one
**shared** `remotebuild` keypair across hosts (per-host build identities
were an option but barely weighed — the shared key was the working
default).

**Implementation state at backfill**: the machinery is live
(`ssh-identities.nix`, inventory-driven `distributed-builds.nix` from
`constants.buildHosts`, `rotate-secrets.py`, `publish-host-keys.py`), but
only `buzz` and `pricklepants` have committed pubs and inventory entries.
The remaining hosts are enrolled as their keys are published.

## Alternatives Considered

### Per-host build identities
- **Pros**: uniform with host keys; smaller blast radius per host.
- **Cons**: more files; rotation touches every host's knownHosts anyway.
- **Why not**: shared key was the working status quo; barely weighed.

### Auto-generate host keys only, publish nothing
- **Pros**: zero repo content.
- **Cons**: keeps the `ssh yes` prompt and manual rotation pain — the
  original bug.
- **Why not**: this was the status quo being fixed.

## Consequences

### Positive
- No interactive host-key prompts; borg pubs cannot drift from server config.
- Identity rotation = regenerate pair, update sops, commit pub, rebuild.

### Negative
- Pubs are public in a public repo (acceptable: they are public by design).
- Shared `remotebuild` key means rotating it touches all hosts (the rotate
  script's job).

### Open
- Fleet-wide enrollment (pubs + `buildHosts` entries for the remaining
  hosts) still pending.

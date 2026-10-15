# ADR-0008: WireGuard peers driven by committed plaintext JSON

**Date**: 2026-10-14
**Status**: accepted (backfilled 2026-10-15)
**Deciders**: jeromeb

## Context

WireGuard server config lived hand-edited in `modules/wireguard.nix` plus a
sops file for preshared keys. IP allocation on `10.66.66.0/24` was manual
and collision-prone; client onboarding meant hand-generating keys and
assembling configs. The repo is public, so anything committed must be
public-by-design data only.

## Decision

Single source of truth for peers: `global/wireguard-peers.json` (committed
plaintext — server port/addresses/pubkey + per-peer name, pubkey, allowed
IPs). The Nix module reads it with `builtins.fromJSON (builtins.readFile ...)`
and generates interface peers and sops secret declarations. PSKs stay in
`secrets/services/wireguard/secrets.yaml`; client private keys in a separate
`clients.yaml` restricted to admin age keys via a dedicated `.sops.yaml`
rule above the generic services rule. A Python script
(`scripts/wireguard-peers.py`) owns add/list/update/delete, deterministic
CIDR-aware IP allocation, and client `.conf`/QR rendering.

## Alternatives Considered

### Keep peers only in sops
- **Pros**: fully encrypted.
- **Cons**: Nix eval cannot read ciphertext; declarative module would be
  impossible → forced imperative `wg setconf` at deploy time.
- **Why not**: peers are public-by-design (WG pubkeys travel cleartext in
  handshakes); encryption buys nothing and costs declarativity.

### Live `wg set` without rebuild
- **Pros**: instant peer changes.
- **Why not**: non-goal; the tool edits files, the operator rebuilds — one
  config path, no drift between live state and repo.

### Store rendered client `.conf` in clients.yaml
- **Pros**: `show` needs only one decrypt.
- **Cons**: duplicates key + IP list (second source of truth).
- **Why not**: store only the non-derivable `private_key`; re-render on
  demand.

## Consequences

### Positive
- Collision-free deterministic allocation (CIDR containment, not equality).
- One JSON drives all three WG servers; client keys never committed plain.

### Negative
- The JSON must be git-added before builds (flake eval ignores untracked
  files).
- `show`/`export` need the age key to decrypt both sops files (PSK + client
  key).

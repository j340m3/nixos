# ADR-0005: Nebula mesh as the overlay VPN

**Date**: ~2025 (backfilled 2026-10-15)
**Status**: accepted
**Deciders**: jeromeb

## Context

Hosts sit behind NAT, on different LANs, and on VPS networks. Services
(Nextcloud, Immich, builders, DNS) must be reachable host-to-host without
exposing everything publicly. A WireGuard site-bridge exists separately for
clients (ADR-0008); server-to-server traffic needs its own overlay.

## Decision

Run a Nebula mesh (`modules/nebula.nix`) across the fleet on `10.0.0.0/24`,
with `pricklepants` as lighthouse. Host-to-host addressing and DNS use the
Nebula IPs; mesh certs/keys are sops secrets.

## Alternatives Considered

### WireGuard full mesh
- **Pros**: in-kernel, no extra CA.
- **Cons**: peer list grows O(n²); cert-based identity of Nebula fits the
  "add a host, get an identity" flow better.
- **Why not**: WireGuard is kept for *client* VPN access, not mesh.

### Tailscale
- **Pros**: zero-config mesh.
- **Cons**: third-party control plane; keys not fully self-hosted.
- **Why not**: self-hosted lighthouse keeps the fleet independent of a SaaS.

### Yggdrasil
- **Pros**: also present in the repo as an experiment.
- **Cons**: Nebula already carries production traffic.
- **Why not**: experimental module only; not the mesh backbone.

## Consequences

### Positive
- One flat L3 network across NAT/VPS; services bind Nebula IPs.
- Identity is cert-based; hosts authenticate via the Nebula CA.

### Negative
- CA key management is a privileged operation (rotation re-signs every host).
- Lighthouse (`pricklepants`) is a soft single point of discovery.

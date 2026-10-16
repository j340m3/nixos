# ADR-0005: Nebula mesh as the overlay VPN

**Date**: 2025-04-15 (module born on buzz; fleet-wide rollout afterwards)
**Status**: accepted (backfilled 2026-10-15)
**Deciders**: j340m3

## Context

Hosts sit behind NAT, on different LANs, and on VPS networks. Services
(Nextcloud, Immich, builders, DNS) must be reachable host-to-host without
exposing everything publicly. The goals: solve NAT traversal, and stay as
independent and resilient as possible — a decentralized overlay owned by the
fleet, not a SaaS control plane. A WireGuard client-VPN arrived separately
in 2026 (ADR-0008); server-to-server needed its own overlay.

## Decision

Run a Nebula mesh (`modules/nebula.nix`) across the fleet on `10.0.0.0/24`.
`buzz` (10.0.0.1) and `pricklepants` (10.0.0.5) are lighthouses **and**
relays — deliberately a proof of concept for multiple lighthouses, with the
intent that all VPS eventually become lighthouses for maximum resilience.
Per-host certs/keys are sops secrets signed by a shared CA; the Nebula DNS
client points at buzz:53.

## Alternatives Considered

### WireGuard as full mesh
- **Pros**: in-kernel, ubiquitous tooling.
- **Cons**: adding a host means rebuilding *every* host to add the new
  peer — cumbersome at fleet scale.
- **Why not**: Nebula's CA + lighthouse model means adding a host only
  rebuilds that one host.

### Headscale (self-hosted Tailscale control plane)
- **Pros**: familiar Tailscale UX, self-hosted coordination.
- **Cons**: more overhead to run on NixOS; uncertainty whether it supports
  multiple lighthouses the way Nebula does natively.
- **Why not**: overhead and the multi-lighthouse question — resilience was
  the point.

### Yggdrasil
- **Pros**: another decentralized overlay; in the repo as an experiment.
- **Cons**: not adopted as the backbone.
- **Why not**: still an ongoing evaluation — it targets a *different* open
  problem: Nebula traffic between two hosts on the same LAN currently
  routes via a VPS and needs internet; Yggdrasil is being tested for that
  routing issue.

## Consequences

### Positive
- One flat L3 network across NAT/VPS; services bind Nebula IPs.
- Cert-based identity: onboarding a host rebuilds only that host.
- Decentralized: no SaaS dependency; multiple lighthouses as the resilience
  pattern (PoC now, more VPS to follow).

### Negative
- CA key management is a privileged operation (rotation re-signs every host).
- Lighthouse set is currently just two (buzz, pricklepants) — not yet at the
  "all VPS" target.

### Open issues
- The buzz:53 DNS-over-mesh experiment **did not work out**; a new DNS
  concept for the mesh needs to be designed.
- Same-LAN Nebula traffic hairpins through a VPS (needs internet); Yggdrasil
  evaluation ongoing.

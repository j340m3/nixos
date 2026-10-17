# ADR-0000: Update independence with opportunistic cooperation

**Date**: 2024-12-18
**Status**: accepted (guiding principle)
**Deciders**: j340m3

## Context

The fleet spans VPSes, laptops, a uConsole and WSL hosts, updating themselves
unattended every hour. If updating required a builder, a cache host, another
sibling, or the admin's machine to be online, any of those would become a
single point of failure that can strand a host indefinitely. Yet the hosts are
more useful together than apart. This principle states the invariant that
governs every other update/build decision in this repo.

## Decision

**Update independence is a hard invariant.** Every running host updates
itself indefinitely with no other host online; the only required external
endpoints are GitHub (config source) and DNS. Binary caches and sibling
builders are pure accelerators — never required. No host may ever depend on
another host to update.

**Bounded convergence.** Each host converges to current within a bounded time
(hourly autoUpgrade, floating inputs) with zero manual intervention.

**Opportunistic cooperation is strictly best-effort.** When siblings are up,
hosts help each other — distributed builds, a shared binary cache, overlay
connectivity, emergent upgrade stabilization — and none of it may weaken the
independence invariant.

**Long-run: no central forge.** GitHub is today the one central dependency;
the direction is a generic decentralized/self-hostable forge so even the
config source stops being a single point.

Governed decisions: ADR-0003 (floating lock + hourly autoUpgrade), ADR-0005 /
ADR-0008 (overlay connectivity as the cooperation substrate), ADR-0006
(identity keys + distributed builds), ADR-0007 (upgrade-health rollback).

## Alternatives Considered

### Required central build/cache server
- **Pros**: simpler, fast; one place to build.
- **Cons**: its outage strands every host; violates minimal endpoints.
- **Why not**: a required builder is exactly the single point being avoided.

### Fully independent hosts, no cooperation
- **Pros**: trivially satisfies independence.
- **Cons**: wastes idle fleet capacity; every host rebuilds alone.
- **Why not**: cheaper and faster to use siblings when they happen to be up.

### Permanent reliance on a central forge (GH/Hosted)
- **Pros**: zero effort, works today.
- **Cons**: one account/service outage blocks all updates.
- **Why not**: acceptable now, but the direction is a decentralized forge.

## Consequences

### Positive
- No host is a single point of failure; the fleet keeps updating through
  outages of any sibling, builder, or cache.
- Siblings speed and offload each other with no coordination required.

### Negative
- Cooperation is best-effort and invisible, so it is easy to accidentally
  introduce a hard dependency on a sibling or cache — requires vigilance.

### Risks
- Today the invariant is still bounded by GitHub and DNS; losing either
  stops updates until the forge is decentralized.

## Amendments

- **2026-10-16 — cachyos kernels dropped from headless hosts.** Every VPS
  booted a `linuxPackages_cachyos-*` kernel that exists only in
  `cache.chaotic.cx`; if that cache is unreachable the host cannot rebuild —
  a hard dependency on a binary cache, exactly the failure mode the Negative
  consequence below warns about. Removed `boot.kernelPackages` from buzz,
  jessie, mrpotatohead and pricklepants (now stock nixpkgs kernels) and moved
  `inputs.chaotic.nixosModules.default` out of the global `mkHost` into the
  per-host imports of the only remaining cachyos users (rex, lenny, woody).
  Binary caches remain listed globally as best-effort accelerators.

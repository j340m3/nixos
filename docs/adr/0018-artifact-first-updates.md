# ADR-0018: Artifact-first updates for memory-starved hosts

**Date**: 2026-11-13
**Status**: accepted
**Deciders**: jeromeb + grilling session (rebuild memory pressure)
**Knowledge**: docs/wiki/syntheses/artifact-first-updates.md,
docs/wiki/concepts/hardware-edge-stack.md, docs/wiki/concepts/nixos-closure-levers.md

## Context

pricklepants (1 GB RAM / 10 GB disk Ionos VPS) hurts on every rebuild: the
hourly `system.autoUpgrade` and manual rebuilds both evaluate the whole
dendritic flake on the box itself, and the box inherited `max-jobs = 6` from
the remote-builder aspect (`modules/services/remote-builder.nix`) even though
it is itself a 1 GB machine. jessie (1-core/1.8 GB) pays the same eval cost.
Both host live services (vaultwarden/luanti, minecraft) that thrash under
that pressure — the 2026-11-07 pricklepants memory-thrash incident is the
standing example (mem.nix).

The governing constraint (ADR-0000) is unchanged: every host must be able to
update itself in place with **no other host online**. Remote builders and
caches are opportunistic accelerators only.

Two side findings from the session:

- slinky's aarch64 kernel was never cacheable: nothing in the fleet ever
  writes into harmonia (it serves woody's own `/nix/store`, and woody only
  builds x86_64), and the fleet builder entries declared no
  `supportedFeatures` while the kernel build demands
  `requiredSystemFeatures = [ "big-parallel" ]` — so the kernel job could
  never leave the RPi. slinky's own `builder-local` build machine entry had
  been dead since commit `425c717` removed its ssh alias.
- jessie's `zramSwap.enable = false` predates the tmpfs→btrfs switch on `/`
  (the "tmpfs ate the RAM" era, jessie/configuration.nix comment) and no
  longer matches the box it runs on.

Rejected in grilling, on purpose:

- **No memory ceiling on the `nixos-upgrade` unit** (Q5): a `MemoryMax` low
  enough to protect the box would make eval fail forever, i.e. the host
  would never rebuild. The right fix removes the need to eval at all.
- **No ccache revival**: the pre-dendritic attempt (dropped in `b7950c0`)
  added overlay complexity to a problem that is a build-placement problem.

## Decision

Six moves, all verified by eval before landing:

1. **pricklepants build cap**: `nix.settings.max-jobs = mkForce 1` +
   `daemonCPUSchedPolicy = "idle"` (jessie's existing treatment) so the
   local-build fallback can never fork six jobs on 1 GB again.
2. **pricklepants swap**: drop `randomEncryption` on `/dev/vda16`. The
   per-boot random key already bounds exposure to the running session; the
   decrypt tax on every swap-in was pure loss during the thrash episodes.
3. **jessie zram**: re-enabled at `memoryPercent = 50`, ahead of the 4G
   swapfile.
4. **Builder roster features** (`_constants.nix`): builders that can afford
   it (buzz, mrpotatohead, woody) now advertise
   `supportedFeatures = [ "big-parallel" ]` and
   `systems = [ "x86_64-linux" "aarch64-linux" ]` (binfmt emulation is
   already armed on every x86_64 mesh member via remote-builder.nix). The
   1-2 GB builders (pricklepants, jessie) stay featureless and x86_64-only:
   a kernel build on *them* is the bug, not the fix. slinky's dead
   `builder-local` entry is deleted.
5. **Publisher** (`modules/services/artifact-publisher.nix`, on woody):
   hourly at :25, builds `pricklepants`, `jessie` and `slinky` toplevels
   from `github:j340m3/nixos`, keeps one out-link per host under
   `/var/lib/artifact-publisher/roots/<h>` as the only GC root (latest-only;
   everything older is released to woody's hourly 7d GC), regenerates
   `manifest.json` (`{host: {system, rev, built}}`) from the surviving
   links, and serves it via nginx on woody's nebula IP :5001 (mesh-only,
   plain HTTP, both firewall gatekeeping layers). Space guard: skip loudly
   below `minFree` (6G default); Telegram on failure. Building slinky's
   toplevel puts its aarch64 kernel into woody's store — which *is* the
   harmonia cache — so the kernel-caching gap is fixed as a byproduct.
6. **Client** (`modules/system/artifact-update.nix`, on pricklepants +
   jessie): hourly at :05 (fallback eval would have been at :45), curls the
   manifest, validates the entry is a `/nix/store/*-nixos-system-*` path,
   applies each distinct closure **at most once** (state file
   `/var/lib/artifact-update/last-applied`: never re-apply an applied path,
   so a stale manifest can neither clobber a manual rebuild nor loop), then
   `nix-store -r` (signature-checked against the harmonia key in the fleet
   substituters), `nix-env -p system --set`, `switch-to-configuration
   switch`. `systemd.timers.nixos-upgrade.enable` is forced off — the
   nixos-upgrade *unit* stays as the fallback, started by the client's
   `OnFailure` (alongside the usual notify-telegram). `onSuccess` arms
   `nixos-upgrade-health-schedule` where upgradeHealth is enabled, so the
   auto-rollback safety net still covers artifact switches.

ADR-0000 compliance: every failure mode — manifest unreachable, malformed
entry, failed substitution — falls back to the unchanged local
eval-and-build path. With woody dark, a client behaves exactly as before
ADR-0018, just with capped parallelism.

## Alternatives Considered

### Alternative 1: Shrink the eval (nixpkgs narrowing, comin, memory ceilings)
- **Pros**: no second host in the update path.
- **Cons**: eval cost is structural (dendritic fleet-wide options); ceilings
  risk never-rebuilding hosts (rejected in Q5).
- **Why not**: does not reach the goal of *not paying eval on the box*.

### Alternative 2: Delegate builds to fleet builders (fix big-parallel only)
- **Pros**: one-line-ish change, keeps self-update semantics.
- **Cons**: delegation still requires the *client* to eval (the actual pain
  point), and emulated builds on small builders are pathological.
- **Why not**: fixes slinky's kernel build placement but not the eval bill.

### Alternative 3: Local eval + nix copy to harmonia (publisher on client side)
- **Pros**: clients push their own artifacts; no publisher trust.
- **Cons**: every client pays the full build it was trying to avoid;
  harmonia would need a write path (it is a read-only view of woody's
  store).
- **Why not**: inverts the load onto exactly the hosts that cannot carry it.

## Consequences

### Positive
- pricklepants' happy-path update is download + switch: no flake eval, no
  build on the box. jessie likewise, and both keep local-build fallbacks
  with sane parallelism.
- slinky's kernel lands in a cache it already trusts; fleet builders with
  binfmt + big-parallel can take its aarch64 jobs opportunistically.
- The manifest is latest-only, so store growth on woody is bounded by its
  7d GC; the space guard protects woody's own upgrade headroom.

### Negative
- No auto-reboot in the artifact path: `switch-to-configuration switch`
  activates services but a kernel bump only takes effect at the next manual
  reboot. The autoUpgrade fallback (rebootWindow 22:00–08:00) only runs on
  artifact failure. Watch this on VPSes.
- Two clock-adjacent new timers (:05/:25) join the :15/:15/:45 fleet cron
  chorus; failures report via the existing Telegram template.
- The client trusts the manifest's *path* (not its content): a mesh peer
  could serve a manifest pointing at an older *signed* system closure. The
  at-most-once guard makes a downgrade one-shot rather than looping, and
  mesh membership is cert-gated — accepted risk for a mesh-internal,
  untrusted-content transport.

### Risks
- woody disk: three closures (one aarch64, ~5–15G unique) against ~17G free.
  Mitigation: minFree guard (skips loudly), user plans NAS headroom; slinky
  can be dropped from `artifactPublisher.hosts` in one line if it strains.
- slinky's toplevel build hits the known IFD wall (`dtbs-filtered`) when
  *evaluated* on x86_64 (`just check` still skips it) — but the publisher
  *builds* it, which is exactly where that cost belongs: on woody, emulated,
  once per input bump instead of hourly on the Pi.

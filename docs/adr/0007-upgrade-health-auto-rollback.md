# ADR-0007: Upgrade-health auto-rollback on headless hosts

**Date**: 2026-10-03
**Status**: accepted (backfilled 2026-10-15)
**Deciders**: j340m3

## Context

Hourly unattended upgrades (ADR-0003) mean a build can succeed while the
activated system is broken (a unit that cannot start, a missing mount). The
host stays broken until a human reads an alert. `nixos-rebuild switch` is
atomic, but that only covers *failed builds*, not *successful-but-broken*
activations.

## Decision

Opt-in module `modules/common/upgradeHealth.nix`: after boot and after each
successful `nixos-upgrade.service`, sleep `settleDelay` (default 5m), then
check `systemctl --failed`. If any failed units remain (after filtering out
the upgrade/notify/health units themselves), notify Telegram, write a guard
file keyed on the failed-unit set, `nixos-rebuild rollback`, and reboot.
Enabled on headless hosts only (`mrpotatohead`, `buzz`, `pricklepants`,
`jessie`). Has rolled back a real broken upgrade in production.

## Alternatives Considered

### Alert-only (Telegram, no auto-rollback)
- **Pros**: human stays in control; no surprise reboots.
- **Cons**: headless hosts sit broken until someone reads the alert.
- **Why not**: the point is self-healing without a human.

### Human rollback only (status quo)
- **Pros**: no new module.
- **Cons**: requires noticing the breakage and acting — exactly what
  unattended hourly upgrades removed from the loop.
- **Why not**: this was the gap being fixed.

### systemd timer on the health check
- **Pros**: natural scheduling primitive.
- **Cons**: a timer *activates* a unit, it does not wait for another unit;
  the design explored this and found timers cannot express "run after
  upgrade finishes" here. `OnSuccess=` on the upgrade unit is the correct
  hook.
- **Why not**: semantically wrong primitive.

### Guard keyed on the generation link
- **Pros**: simple to read.
- **Cons**: every hourly autoUpgrade mints a new generation link even when
  the store path is unchanged → guard never trips → rollback+reboot loop
  every hour.
- **Why not**: keyed on the failed-unit set instead: one rollback per
  distinct failure; guard cleared when healthy.

### Commit flake.lock / release branch instead of rollback
- **Pros**: prevents breakage upstream of the host.
- **Cons**: orthogonal; locked delivery needs a human/CI gate (parked as
  follow-ups in the design).
- **Why not**: does not replace repair for already-broken activations.

## Consequences

### Positive
- Headless hosts self-heal from broken activations without a human.
- Guard bounds damage: one rollback per distinct failure set, no loops.

### Negative
- Rollback is a reboot — unacceptable for graphical hosts (unsaved work);
  they stay out of scope.
- Pre-existing failed units cost one unnecessary reboot, then the guard
  stops it.

### Risks
- Requires `boot.loader.grub.configurationLimit >= 2` so a previous
  generation survives; never set to 1 on enabled hosts.
- Fails that don't produce failed units (HTTP 500s) are not detected —
  probes are a parked follow-up.

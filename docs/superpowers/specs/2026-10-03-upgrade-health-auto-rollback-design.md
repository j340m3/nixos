# Upgrade health check with automatic rollback

Date: 2026-10-03
Status: proposed

## Context

Hosts update themselves: `system.autoUpgrade` runs hourly (`modules/common/update.nix`),
`flake.lock` is gitignored, and the rebuild fetches fresh inputs with
`--no-write-lock-file`. No host depends on another host, and no human has to bump
anything.

That already gives one safety property for free: `nixos-rebuild switch` is atomic, so a
failed evaluation or build leaves the running system untouched.

It does not cover the other half. When the build succeeds and the activated system is
broken — a unit that cannot start, a mount that never appears — the host stays broken
until someone reads the alert. Rolling-release style delivery makes this more likely,
because every host can pull a new upstream state unattended within the hour.

Goal: a headless host notices its own broken state and returns to the previous
generation without a human.

## Goals

- A headless host rolls itself back when systemd reports failed units, after an upgrade
  and on boot, with no manual step.
- The delivery model stays exactly as it is: floating lock, hourly autoUpgrade, no
  host-to-host or human dependency.
- Any rollback attempt is visible to the user over the existing Telegram notification.

## Non-goals

- Committing `flake.lock`, or switching nixpkgs to a release branch. Both stay open as
  separate follow-ups.
- Graphical hosts. The repair action is a reboot, which can cost unsaved work.
- Failures that do not show up as failed units. A running service returning errors, a
  site answering 500, is not detected.
- Changing `autoUpgrade` policy: it stays on `switch`, not `boot`.

## Design

### Components

New module `modules/common/upgradeHealth.nix`, added to the explicit import list in
`modules/common/default.nix`. Every host that imports `modules/common` loads the module;
it does nothing unless the host opts in.

Options:

- `upgradeHealth.enable` (bool, default `false`)
- `upgradeHealth.settleDelay` (string, default `"5min"`)

Units:

- `systemd.services.nixos-upgrade-health`: `Type = "oneshot"`,
  `wantedBy = [ "multi-user.target" ]`, `ExecStartPre` sleeping `settleDelay`.
  This runs the check on every boot, which is the boot window.
- `systemd.services.nixos-upgrade.onSuccess = [ "nixos-upgrade-health.service" ]`:
  the upgrade window. `nixos-upgrade.service` runs `nixos-rebuild switch` and
  exits 0, so `OnSuccess=` activates the check afterwards.

There is deliberately no timer. `systemd.timers.<name>.timerConfig.Unit` names
the unit the timer *activates* when it elapses; it does not make the timer wait
for that unit, and `OnUnitActiveSec` is counted from that unit's last
activation. A timer configured that way therefore re-activates the named unit and
never starts the check, which has no other trigger. `switch-to-configuration.service`
does not exist at the pinned nixpkgs revision, so there is no unit to wait for
even in principle.

Both paths carry the same single delay, the `ExecStartPre`. The upgrade path must
not run the check with no delay at all: that would judge the host while the
upgrade's own units are still settling. Running the check twice in one boot is
harmless, because the check is idempotent.

Enabled on: `mrpotatohead`, `buzz`, `pricklepants`, `jessie`.

Not enabled on `bootstrap`: it does not import `modules/common`, so the
`upgradeHealth` option does not exist there. Adding that import would switch on
`system.autoUpgrade` and its sops secrets, which is a much larger change than
this feature.

Not enabled on `bootstrap-impermanent`: impermanence runs there with a tmpfs root, so a
guard file under `/var/lib` is lost on every boot, the guard would never trip, and the
host could loop rolling back. If that host ever needs this, the guard has to live on a
persistent path.

### Data flow

1. Either `multi-user.target` (boot) or a successful `nixos-upgrade.service`
   (unattended upgrade) activates `nixos-upgrade-health.service`.
2. `ExecStartPre` sleeps `settleDelay`. This is the only delay in the design.
3. The script creates `/var/lib/nixos-upgrade-health` first, so the guard read in step 4
   never meets a missing directory under `set -e`.
4. The check runs `systemctl --failed --plain --no-legend`, then drops this feature's
   own units from the result: `nixos-upgrade-health.service` and every
   `notify-telegram@<unit>.service`. A failed unit survives a `nixos-rebuild switch`,
   so on a later good generation this service would otherwise find itself listed and
   roll back a perfectly healthy host; and a host missing its sops telegram secrets
   fails the notify units permanently, which by itself is not a reason to roll back.
   The match is anchored at the start of the line, so a unit merely named
   `notify-telegram-daemon.service` is not excluded.
   If the list is now empty, delete the guard file, log one line and exit 0. This is
   the normal path and stays quiet. Clearing the guard is what lets a later, unrelated
   failure trigger a fresh rollback instead of being mistaken for one already handled.
   If the check itself cannot run, the unit fails and nothing is rolled back, which is
   the safe direction.
5. On a failed unit:
   1. Take the first failed unit name from the filtered list and start
      `notify-telegram@<unit>.service` with `--no-block`. That reuses the existing
      notification, which names the host, the unit, the exit code, the unit's status
      tail and its last journal lines. Notification is attempted before the guard
      check, so a guard refusal is reported too, and a notification that fails or is
      slow never blocks the rollback.
   2. Compare the filtered list with `/var/lib/nixos-upgrade-health/rolled-back-from`.
      If they are equal, this exact set of failures has already been rolled back once:
      log, exit 1, and do not roll back again.
   3. Otherwise write the filtered list to that file.
6. Run `nixos-rebuild rollback`, called by absolute store path and with no flake
   argument, so it works from the stored profile even when the flake ref is what
   is broken, and does not depend on a `PATH` that systemd units do not have.
7. `systemctl reboot`.

### Why the guard is keyed on the failure, not the generation

`readlink /nix/var/nix/profiles/system` returns a generation *link* such as
`system-42-link`, and every hourly `autoUpgrade` mints a new link even when the
store path behind it did not change. A guard holding that value therefore differs
from the current value after every hour, never trips, and any persistently failed
unit produces a rollback plus a reboot every hour, forever, with a Telegram
message each time.

Keying the guard on the failed-unit list bounds that at one rollback per distinct
failure set: after the first rollback for a failing unit, the next run sees the
same list on the fallback generation and refuses. When the host becomes healthy
again the guard is deleted, so a later unrelated failure can roll back.

The guard is written before the rollback, so a rollback that itself fails is not
retried on every trigger. The earlier objection that this would permanently
disarm the host rested on the generation key, which no longer exists.

Every binary in the script is referenced by absolute store path, including `systemctl`,
`install`, `grep`, `rm`, `cat` and `systemctl reboot`. A unit's `PATH` is not a shell's,
and a rollback that cannot run is worse than no rollback at all.

### Error handling

- If `nixos-rebuild rollback` fails, the oneshot fails and does not reboot. The host
  stays in its current state, and the reason is in the journal and on Telegram. A failed
  rollback never turns into a reboot into a worse state.
- The guard file stops a rollback that did not fix anything from repeating, keyed on the
  failed-unit list so that one broken unit costs one rollback and one reboot.
- `systemctl --failed` also lists units that were already failing before the upgrade. A
  rollback cannot fix those, so the cost is one unnecessary reboot, after which the
  guard stops the loop.
- Rollback ignores the 22:00-08:00 `autoUpgrade` reboot window on purpose: it is a
  repair, not an upgrade.
- The guard path is a single directory created by the check. No other state is kept.

### Prerequisites

- A previous generation must exist. `boot.loader.grub.configurationLimit` must stay at
  2 or more; `pricklepants` is already at 2. Never set it to 1 on a host with this
  enabled.
- `nix.gc` with `--delete-older-than 7d` does not remove the current or previous system
  profile links, so the rollback target survives garbage collection.
- `settleDelay` defaults to `5min`, which is longer than the slowest activation observed
  so far, but a slow activation such as a database reindex can exceed it. Raise the
  option on a host that needs more time.

## Testing

The repo has no test framework, so verification is manual on a host:

1. Evaluate every headless host: `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`.
2. Build the unit, not just evaluate it, so the generated shell is actually run through
   shellcheck: `nix build --no-link --impure --expr '(builtins.getFlake "git+file:///home/jeromeb/code/github/nixos").nixosConfigurations.mrpotatohead.config.systemd.units."nixos-upgrade-health.service".unit'`.
   `systemd.units` lists units whether or not anything activates them, so this proves the
   script compiles, not that the check runs.
3. Assert the triggers, not the unit's existence:
   `nix eval --impure --json --expr 'let c = (builtins.getFlake "git+file:///home/jeromeb/code/github/nixos").nixosConfigurations.mrpotatohead.config; in { boot = c.systemd.services."nixos-upgrade-health".wantedBy; upgrade = c.systemd.services.nixos-upgrade.onSuccess; delay = c.systemd.services."nixos-upgrade-health".preStart; }'`
   Expect `boot = ["multi-user.target"]`, `upgrade = ["nixos-upgrade-health.service"]` and
   `delay` ending in `sleep 5min`.
4. Healthy path: `systemctl start nixos-upgrade-health.service`. Expect exit 0 and one
   log line, and `/var/lib/nixos-upgrade-health/rolled-back-from` to be absent afterwards.
5. Unhealthy path without a real rollback: create a throwaway failed unit, run the check
   once so the guard file holds that unit's list, then run it again. Expect the Telegram
   notification and the "already rolled back from this same set of failed units" log,
   exit 1, and no rollback and no reboot on the second run. This exercises detection, the
   guard and the notification while making the destructive step unreachable after the
   first invocation. Clean up with `systemctl reset-failed <unit>` and
   `rm /var/lib/nixos-upgrade-health/rolled-back-from`.
6. Confirm the rollback target exists: `nixos-rebuild list-generations`.
7. After enabling on a live host, watch the first automatic upgrade:
   `journalctl -u nixos-upgrade-health`.

## Rollout

1. Add the module, its import and the options, default off. No host changes behaviour.
2. Enable on `mrpotatohead`, run the build, the healthy and simulated-failure checks there.
3. Enable on `buzz`, `pricklepants` and `jessie`.
4. Observe one autoUpgrade cycle per host before enabling the next.

## Follow-ups, deliberately not in this design

- Commit `flake.lock` for reproducibility and staged rollout. Needs a human or CI gate,
  which trades away some of the "newest state, no gate" property.
- Move nixpkgs to a release branch to lower the breakage rate upstream.
- Replace the failed-units check with per-host probes, or add HTTP-level probes for
  services that stay up while broken.
- Extend to graphical hosts with a much longer settle delay.
- Drop the `nixpkgs-master` input from `flake.nix`. Its only consumer is the commented-out
  `pkgsUnstable` block at `modules/common/update.nix:35`.
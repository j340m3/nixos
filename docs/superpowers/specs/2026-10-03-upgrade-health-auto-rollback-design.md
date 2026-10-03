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

- `systemd.timers.nixos-upgrade-health`: `Unit = "switch-to-configuration.service"`,
  `OnUnitActiveSec = config.upgradeHealth.settleDelay`, `Persistent = false`.
  `switch-to-configuration.service` goes active on every boot and after every
  `nixos-rebuild switch`, so this single timer covers both failure windows with no
  further wiring.
- `systemd.services.nixos-upgrade-health`: `Type = "oneshot"`, runs the check.

Enabled on: `mrpotatohead`, `buzz`, `pricklepants`, `jessie`, `bootstrap`.

Not enabled on `bootstrap-impermanent`: impermanence runs there with a tmpfs root, so a
guard file under `/var/lib` is lost on every boot, the guard would never trip, and the
host could loop rolling back. If that host ever needs this, the guard has to live on a
persistent path.

### Data flow

1. `switch-to-configuration.service` becomes active, by boot or by rebuild.
2. The timer waits `settleDelay`.
3. The script creates `/var/lib/nixos-upgrade-health` first, so the guard read in step 4
   never meets a missing file under `set -e`.
4. The check runs `systemctl --failed --quiet`. Exit 1 means nothing is failed: log one
   line and exit 0. This is the normal path and stays quiet. If the check itself cannot
   run, the unit fails and nothing is rolled back, which is the safe direction.
5. On a failed unit:
   1. Take the first failed unit name from
      `systemctl --failed --plain --no-legend` and start
      `notify-telegram@<unit>.service` with `--no-block`. That reuses the existing
      notification, which names the host, the unit, the exit code, the unit's status
      tail and its last journal lines.
   2. Read the current generation from
      `readlink /nix/var/nix/profiles/system`.
   3. Compare with `/var/lib/nixos-upgrade-health/rolled-back-from`.
      If it matches, we already tried rolling back from this generation: log, exit 1,
      and do not roll back again.
   4. Otherwise write the generation to that file.
5. Run `nixos-rebuild rollback`, called by absolute store path and with no flake
         argument, so it works from the stored profile even when the flake ref is what
         is broken, and does not depend on a `PATH` that systemd units do not have.
      6. `systemctl reboot`.

Every binary in the script is referenced by absolute store path, including `systemctl`,
`readlink` and `systemctl reboot`. A unit's `PATH` is not a shell's, and a rollback that
cannot run is worse than no rollback at all.

### Error handling

- If `nixos-rebuild rollback` fails, the oneshot fails and does not reboot. The host
  stays in its current state, and the reason is in the journal and on Telegram. A failed
  rollback never turns into a reboot into a worse state.
- The guard file stops a rollback that did not fix anything from repeating.
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
2. Healthy path: `systemctl start nixos-upgrade-health.service`. Expect exit 0 and one
   log line.
3. Unhealthy path without a real rollback: create a throwaway failed unit, pre-seed
   `/var/lib/nixos-upgrade-health/rolled-back-from` with the current generation, then
   run the check. Expect the Telegram notification, the "already rolled back" log, exit
   1, and no rollback and no reboot. This exercises detection, the guard and the
   notification while making the destructive step unreachable.
4. Confirm the rollback target exists: `nixos-rebuild list-generations`.
5. After enabling on a live host, watch the first automatic upgrade:
   `journalctl -u nixos-upgrade-health`.

## Rollout

1. Add the module, its import and the options, default off. No host changes behaviour.
2. Enable on `mrpotatohead`, run the healthy and simulated-failure checks there.
3. Enable on `buzz`, `pricklepants`, `jessie`, `bootstrap`.
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
# Upgrade Health Check Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A headless NixOS host detects its own broken state (`systemd` reports failed units) after an upgrade or on boot, notifies over Telegram, and returns to the previous generation by itself.

**Architecture:** One new opt-in module, `modules/common/upgradeHealth.nix`, defines a oneshot that checks `systemctl --failed` after a settle delay. It is triggered two ways: `wantedBy = [ "multi-user.target" ]` covers boot, and `systemd.services.nixos-upgrade.onSuccess = [ "nixos-upgrade-health.service" ]` covers a successful unattended upgrade. The settle delay is an `ExecStartPre` inside the service, so both windows get exactly one delay. On failure it fires the existing `notify-telegram@<unit>.service`, writes the filtered failed-unit list to a guard file, then runs `nixos-rebuild rollback` and reboots. The guard, keyed on that list, stops a rollback that did not help from repeating. Delivery is unchanged: floating lock, hourly autoUpgrade on `switch`.

**Tech Stack:** NixOS modules, systemd (oneshot, `wantedBy`, `onSuccess`, `ExecStartPre`), POSIX shell in a systemd `script`, sops-nix secrets (consumed via the existing notify unit).

**Spec:** `docs/superpowers/specs/2026-10-03-upgrade-health-auto-rollback-design.md`

**Testing note:** this repo has no test framework and this feature is systemd units, so the checkable result is the generated unit text plus live behavior on a real host. Every task therefore ends in an explicit command with the output that means it passed. Do not add a test harness for this.

**Live-host checklist — the check must actually run, not merely exist.**
`config.systemd.units` lists a unit whether or not anything activates it, and
`systemctl list-unit-files` likewise only proves the file is installed. Every live-host step
below therefore asserts a *trigger* or an *observed execution*:

- boot window: `systemctl is-enabled nixos-upgrade-health.service` is `enabled`
  (the `multi-user.target.wants` symlink exists), and the unit appears in
  `journalctl -u nixos-upgrade-health` after a boot with no manual `systemctl start`.
- upgrade window: `systemctl show -p OnSuccess nixos-upgrade.service` is
  `nixos-upgrade-health.service`, and the health check's journal shows an entry roughly
  `settleDelay` *after* the matching `nixos-upgrade` entry.
- settle delay present: the journal's healthy line lands ~5min after the start, not
  instantly. An instant line means the delay was dropped, which would judge the host
  while activation is still settling.
- no stale trigger: `systemctl is-active nixos-upgrade-health.timer` reports no such
  unit. If a timer reappears, the check is inert again, because
  `timerConfig.Unit` names the unit the timer activates, not one it waits for.

## Global Constraints

- Delivery model does not change: `flake.lock` stays gitignored, `--no-write-lock-file` stays, `autoUpgrade` stays on `switch`, never `boot`.
- Enabled only on `mrpotatohead`, `buzz`, `pricklepants` and `jessie`. Never on `bootstrap`: it does not import `modules/common`, so the option does not exist there, and adding that import would switch on `system.autoUpgrade` and its sops secrets. Never on `bootstrap-impermanent` (impermanence makes `/var/lib` tmpfs, so the guard file is lost every boot and the host could loop). Never on graphical hosts.
- Health signal is exactly the set of failed systemd units. No HTTP probes, no per-host probe lists, no health endpoints.
- Guard path is exactly `/var/lib/nixos-upgrade-health/rolled-back-from`, holding the filtered failed-unit list from the last rollback attempt. Not the generation: hourly `autoUpgrade` mints a new profile link every time even when the store path is unchanged, so a generation key never matches and a broken unit rolls the host back and reboots it every hour.
- Every binary is referenced by absolute store path: `${pkgs.systemd}/bin/systemctl`, `${pkgs.coreutils}/bin/{install,grep,rm,cat}`, `${pkgs.nixos-rebuild}/bin/nixos-rebuild`. A unit's `PATH` is not a shell's; this repo has already shipped three units that failed on exactly this.
- `settleDelay` defaults to `"5min"` and is used as the service's `ExecStartPre`.
- The check is triggered by `multi-user.target` on boot and by `nixos-upgrade.onSuccess` on upgrade. There is no timer: `timerConfig.Unit` names the unit the timer activates, not one it waits for, and `switch-to-configuration.service` does not exist at the pinned nixpkgs revision.
- The rollback must not respect the 22:00-08:00 `autoUpgrade` reboot window. It is a repair.
- If the check itself cannot run, roll nothing back and fail the unit.
- If `nixos-rebuild rollback` fails, do not reboot.
- `boot.loader.grub.configurationLimit` stays at 2 or more on enabled hosts.
- No files created outside `modules/common/upgradeHealth.nix`, plus these plan and spec documents.
- One commit per task. Push after each commit, since hosts deploy from `github:j340m3/nixos`.

## Review Focus

Five input classes the spec implies that no step above naturally exercises. Each has a pinning step in the task that owns the code.

1. **A failed unit whose name contains characters `systemctl` escapes in tree output.** Expect the *verbatim* unit name to reach `notify-telegram@`, not a `\x2d` mangled one. Pinned by Task 2 step 6.
2. **Nothing to roll back to**, e.g. the first generation after install, so `nixos-rebuild rollback` fails. Expect no reboot and a failed unit. Pinned by Task 2 step 7.
3. **A unit that was already failing before the upgrade.** Expect one rollback attempt, then the guard stops it — not an endless loop. Pinned by Task 2 step 6.
4. **Telegram secrets absent, so the notify unit itself fails.** Expect the rollback to proceed anyway, because notification is started non-blocking. Pinned by Task 2 step 6.
5. **A slow activation longer than `settleDelay`.** Expect the option to exist and be raisable per host, not a hardcoded delay. Pinned by Task 1 step 3.

---

### Task 1: The opt-in module, its options and the check script

**Files:**
- Create: `modules/common/upgradeHealth.nix`
- Modify: `modules/common/default.nix` (add one import line to the existing `imports` list)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - option `upgradeHealth.enable` (bool, default `false`)
  - option `upgradeHealth.settleDelay` (string, default `"5min"`)
  - when enabled: `systemd.services.nixos-upgrade-health` and `systemd.services.nixos-upgrade.onSuccess`
  - when disabled: neither exists at all, on any host

- [ ] **Step 1: Create `modules/common/upgradeHealth.nix`**

Module signature `{ config, lib, pkgs, ... }:`. `enable` is `lib.mkEnableOption "roll back the host when systemd reports failed units"`. `settleDelay` is `lib.types.str`, default `"5min"`, described as how long to wait after the check is triggered before judging the host.

Both definitions live under `config = lib.mkIf config.upgradeHealth.enable { ... }`. Service: `wantedBy = [ "multi-user.target" ]` (the boot window), `Type = "oneshot"` via `serviceConfig`, and `preStart = "${pkgs.coreutils}/bin/sleep ${config.upgradeHealth.settleDelay}"` (the single settle delay). Upgrade window: `systemd.services.nixos-upgrade.onSuccess = [ "nixos-upgrade-health.service" ]`, guarded with `lib.mkIf config.system.autoUpgrade.enable` so it cannot conjure a stub unit on a host without autoUpgrade.

The `script`, verbatim:

```sh
guard=/var/lib/nixos-upgrade-health
${pkgs.coreutils}/bin/install -d -m 0755 "$guard"
failed=$(${pkgs.systemd}/bin/systemctl --failed --plain --no-legend)
failed=$(printf '%s\n' "$failed" | ${pkgs.coreutils}/bin/grep -E -v '^(nixos-upgrade-health\.service|notify-telegram@[^ ]+) ' || true)
if [ -z "$failed" ]; then
  ${pkgs.coreutils}/bin/rm -f "$guard/rolled-back-from"
  echo "upgrade-health: no failed units, nothing to do"
  exit 0
fi
nl='
'
first=${failed%%"$nl"*}
unit=${first%% *}
echo "upgrade-health: $unit failed"
${pkgs.systemd}/bin/systemctl start --no-block "notify-telegram@$unit.service" ||
  echo "upgrade-health: notification for $unit failed, continuing with the rollback"
if [ "$(${pkgs.coreutils}/bin/cat "$guard/rolled-back-from" 2>/dev/null || true)" = "$failed" ]; then
  echo "upgrade-health: already rolled back from this same set of failed units, not rolling back again"
  exit 1
fi
printf '%s\n' "$failed" > "$guard/rolled-back-from"
${pkgs.nixos-rebuild}/bin/nixos-rebuild rollback
echo "upgrade-health: rolled back, rebooting"
${pkgs.systemd}/bin/systemctl reboot
```

Decisions the script body fixes, so do not re-derive them:

- The spec says `systemctl --failed --quiet`. This script uses the list form instead, because one call then also yields the unit name, and `--quiet`'s exit code 1 for "nothing failed" would abort a `set -e` script.
- The self-filter excludes this service and every `notify-telegram@<unit>.service`, anchored at the start of the line so `notify-telegram-daemon.service` is not caught. A failed unit survives a switch, and a host without its sops telegram secrets fails the notify units permanently; neither is a reason to roll back.
- The unit name is taken by parameter expansion rather than `head -n 1 | cut -d' ' -f1`: a pipeline that stops reading early can raise SIGPIPE, which `systemd.enableStrictShellChecks` turns into a failed unit.
- The guard holds the filtered failed-unit list, not the generation. Keyed on the generation, hourly `autoUpgrade` mints a fresh `system-<n>-link` every hour even when the store path is unchanged, so the guard never matches and a persistently broken unit rolls the host back and reboots it every hour, with a Telegram message each time.
- A healthy run deletes the guard file, so a later unrelated failure can roll back.
- The guard read tolerates a missing file (`|| true`) so the first run cannot abort under `set -e`.
- Notification is started before the guard check and with `--no-block`, so a slow or failing Telegram call cannot delay or block the rollback. It carries `|| echo`, so a missing notification never blocks either.
- `install -d` runs first, so the guard directory always exists for the write.
- No `set +e` anywhere: a failure of any command must leave the unit failed rather than continue into a reboot.

- [ ] **Step 2: Add the import to `modules/common/default.nix`**

Add `./upgradeHealth.nix` to the `imports` list in `/home/jeromeb/code/github/nixos/modules/common/default.nix`, keeping the file's existing one-per-line style and its commented-out entries untouched. Place it after `./update.nix`.

- [ ] **Step 3: Verify every host still evaluates and no unit appears**

Run:

```bash
cd /home/jeromeb/code/github/nixos
nixfmt modules/common/upgradeHealth.nix modules/common/default.nix
for h in mrpotatohead buzz pricklepants jessie bootstrap bootstrap-impermanent woody rex sid slinky lenny zurg; do
  printf '%-20s ' "$h"
  nix eval --no-write-lock-file --raw ".#nixosConfigurations.$h.config.system.build.toplevel.drvPath" >/dev/null \
    && echo OK || echo FAIL
done
```

Expected: `OK` for all 12.

Then confirm the units are absent while disabled, and that `settleDelay` is a real, overridable option rather than a hardcoded value:

```bash
nix eval --impure --json --expr '
  let c = (builtins.getFlake "git+file:///home/jeromeb/code/github/nixos").nixosConfigurations.mrpotatohead.config;
  in { enable = c.upgradeHealth.enable; settleDelay = c.upgradeHealth.settleDelay;
       serviceExists = c.systemd.services ? nixos-upgrade-health; }'
```

Expected: `{"enable":false,"settleDelay":"5min","serviceExists":false}`. This is what pins Review Focus item 5: `settleDelay` resolves through the option, so a host can raise it.

- [ ] **Step 4: Commit**

```bash
git add modules/common/upgradeHealth.nix modules/common/default.nix
git commit -m "Add opt-in upgrade health check module"
git push
```

---

### Task 2: Enable on mrpotatohead and prove all three paths

**Files:**
- Modify: `hosts/headless/mrpotatohead/default.nix` (add `upgradeHealth.enable = true;`)

**Interfaces:**
- Consumes: `upgradeHealth.enable`, `upgradeHealth.settleDelay`, and the two unit names from Task 1.
- Produces: on `mrpotatohead` only, the check is triggered on boot and after an upgrade, and its script is verified against Review Focus items 1-4.

- [ ] **Step 1: Enable the option**

In `/home/jeromeb/code/github/nixos/hosts/headless/mrpotatohead/default.nix`, add to the host's top-level attribute set, next to the other `services.*`/`system.*` settings rather than in a comment:

```nix
upgradeHealth.enable = true;
```

- [ ] **Step 2: Format and evaluate**

```bash
nixfmt hosts/headless/mrpotatohead/default.nix
nix eval --no-write-lock-file --raw ".#nixosConfigurations.mrpotatohead.config.system.build.toplevel.drvPath"
```

Expected: a store path, exit 0.

- [ ] **Step 3: Assert the triggers, not the unit's existence**

`systemd.units` lists a unit whether or not anything activates it, so its presence
proves nothing. Assert the trigger data instead:

```bash
nix eval --impure --json --expr '
  let c = (builtins.getFlake "git+file:///home/jeromeb/code/github/nixos").nixosConfigurations.mrpotatohead.config;
  in { bootTrigger = c.systemd.services."nixos-upgrade-health".wantedBy;
       upgradeTrigger = c.systemd.services.nixos-upgrade.onSuccess;
       settleDelay = c.systemd.services."nixos-upgrade-health".preStart;
       timerGone = !(c.systemd.timers ? nixos-upgrade-health); }' | python3 -m json.tool
```

Expected: `bootTrigger` contains `"multi-user.target"`, `upgradeTrigger` contains
`"nixos-upgrade-health.service"`, `settleDelay` ends in `sleep 5min`, and `timerGone` is
`true`.

Then check the script's store paths and build the unit, because a build is what proves the
generated script compiles, which an eval cannot reach. Note that this does not shellcheck
the script on these hosts: `systemd.enableStrictShellChecks` is false here, so for that
coverage build the evaluated `script` through `pkgs.writeShellApplication` rather than
turning the option on globally.

```bash
nix build --no-link --impure --expr \
  '(builtins.getFlake "git+file:///home/jeromeb/code/github/nixos").nixosConfigurations.mrpotatohead.config.systemd.units."nixos-upgrade-health.service".unit'
```

Expected: exit 0. In `script`, every occurrence of `systemctl`, `install`, `grep`, `rm`,
`cat` and `nixos-rebuild` must be preceded by `/nix/store/`. If any is bare, or if the
build fails, stop and fix Task 1's script before continuing.

- [ ] **Step 4: Commit and push**

```bash
git add hosts/headless/mrpotatohead/default.nix
git commit -m "Enable the upgrade health check on mrpotatohead"
git push
```

- [ ] **Step 5: Deploy and prove the healthy path on the live host**

```bash
sudo nixos-rebuild switch --flake 'github:j340m3/nixos' --no-write-lock-file
systemctl is-enabled nixos-upgrade-health.service
systemctl is-active nixos-upgrade-health.timer 2>&1 | head -1   # expect: inactive / no such
sudo systemctl start nixos-upgrade-health.service
echo "exit=$?"
journalctl -u nixos-upgrade-health -n 5 --no-pager
ls -l /var/lib/nixos-upgrade-health/rolled-back-from 2>&1   # expect: no such file
```

Expected: the service is `enabled` (the `multi-user.target` symlink exists), there is no
`nixos-upgrade-health.timer` at all, `systemctl start` returns `exit=0`,
`journalctl` shows `upgrade-health: no failed units, nothing to do` about five minutes
after the start (that gap is the `ExecStartPre` settle delay — if it returns instantly,
the delay is not wired in), and the guard file does not exist, because a healthy run
deletes it.

Record the boot time before continuing:

```bash
who -b
```

- [ ] **Step 6: Prove the unhealthy path without letting it roll back**

The guard holds the failed-unit list, not the generation, so pre-seeding it means running
the check once against the throwaway unit and letting the first run write the guard. The
first run does reach `nixos-rebuild rollback`, which is destructive, so do this on a host
you are willing to roll back; the second run is the safe one that proves the guard.

```bash
sudo mkdir -p /var/lib/nixos-upgrade-health
sudo systemd-run --unit=health-test-fail.service --property=Type=oneshot /bin/false
sleep 2
systemctl --failed --plain --no-legend
sudo systemctl start nixos-upgrade-health.service; echo "exit=$?"   # first run: may roll back
cat /var/lib/nixos-upgrade-health/rolled-back-from
# second run, with the guard already holding this exact failed-unit list
sudo systemctl start nixos-upgrade-health.service; echo "exit=$?"
journalctl -u nixos-upgrade-health -n 10 --no-pager
systemctl status "notify-telegram@health-test-fail.service" --no-pager | head -5
who -b
```

Expected, on the **second** run, and this is what pins Review Focus items 1, 3 and 4:

- `systemctl --failed --plain --no-legend` lists `health-test-fail.service` and no `\x2d` escaping.
- The journal shows `upgrade-health: health-test-fail.service failed`, then `upgrade-health: already rolled back from this same set of failed units, not rolling back again`.
- `exit=1`.
- A Telegram message arrived naming `health-test-fail.service` with its exit code and journal line.
- `who -b` is unchanged across the second run: **no reboot happened**.
- Re-running the check does not roll back or reboot again. It does send another message,
  because notification is deliberately attempted before the guard check so that a guard
  refusal is still reported.

Then clean up:

```bash
sudo systemctl reset-failed health-test-fail.service
sudo rm /var/lib/nixos-upgrade-health/rolled-back-from
```

- [ ] **Step 7: Prove that a failing rollback command cannot reach the reboot**

The script's only protection is that a systemd `script` runs under `set -e`, so a non-zero rollback aborts before `systemctl reboot`. Demonstrate that mechanism directly, with no risk to the host, and confirm the rollback target exists:

```bash
sudo bash -c 'set -e; false; echo "reboot would happen here"'; echo "exit=$?"
nixos-rebuild list-generations
```

Expected: `exit=1` with no `reboot would happen here` line printed. `list-generations` shows at least two generations, so a rollback target exists. This is Review Focus item 2: on a host with nothing to roll back to, `nixos-rebuild rollback` exits non-zero and, per the demonstration above, the reboot is never reached.

Do not attempt this by renaming or removing a store path. An inconsistent store on a production VPS costs more than the property is worth.

---

### Task 3: Roll out to the remaining headless hosts

**Files:**
- Modify: `hosts/headless/buzz/default.nix`
- Modify: `hosts/headless/pricklepants/default.nix`
- Modify: `hosts/headless/jessie/default.nix`

`bootstrap` is deliberately not in this list: it does not import `modules/common`, so the
`upgradeHealth` option does not exist there. Adding the import would switch on
`system.autoUpgrade` and its sops secrets, which is far outside this feature.

**Interfaces:**
- Consumes: `upgradeHealth.enable` from Task 1.
- Produces: the option enabled on all four intended headless hosts, none on graphical hosts or `bootstrap-impermanent`.

- [ ] **Step 1: Enable the option on the three remaining hosts**

Add this line to each of the three files above, at the same nesting level as in Task 2:

```nix
upgradeHealth.enable = true;
```

- [ ] **Step 2: Format and evaluate everything**

```bash
cd /home/jeromeb/code/github/nixos
nixfmt hosts/headless/{buzz,pricklepants,jessie}/default.nix
for h in buzz pricklepants jessie bootstrap woody rex sid slinky lenny zurg bootstrap-impermanent; do
  printf '%-22s ' "$h"
  nix eval --no-write-lock-file --raw ".#nixosConfigurations.$h.config.system.build.toplevel.drvPath" >/dev/null \
    && echo OK || echo FAIL
done
```

Expected: `OK` for all 11. `slinky` is expected to fail, because it needs an aarch64
builder this workspace does not have; that is pre-existing and unrelated.

- [ ] **Step 3: Confirm the enabled set is exactly the intended four**

```bash
nix eval --impure --json --expr '
  let f = builtins.getFlake "git+file:///home/jeromeb/code/github/nixos";
  in builtins.mapAttrs
       (_: c: if c ? upgradeHealth then c.upgradeHealth.enable else "option absent")
       f.nixosConfigurations'
```

Expected: `buzz`, `pricklepants`, `jessie` and `mrpotatohead` are `true`;
`bootstrap-impermanent` is `false`; every graphical host is `false`; `bootstrap` reports
`"option absent"`. If `bootstrap-impermanent` is `true`, stop: its tmpfs root makes the
guard file vanish every boot.

Then confirm no enabled host can lose its rollback target, which the spec requires:

```bash
nix eval --impure --json --expr '
  let f = builtins.getFlake "git+file:///home/jeromeb/code/github/nixos";
  in builtins.mapAttrs (_: c:
       if c ? upgradeHealth && c.upgradeHealth.enable
       then c.boot.loader.grub.configurationLimit else null)
       f.nixosConfigurations'
```

Expected: for the four enabled hosts, no value is `1`. `pricklepants` is already `2`, which is the tightest acceptable value; the others inherit the NixOS default of `100`. A `1` means that host can never roll back and the option must be raised there.

- [ ] **Step 4: Commit and push**

```bash
git add hosts/headless/{buzz,pricklepants,jessie}/default.nix
git commit -m "Enable the upgrade health check on the remaining headless hosts"
git push
```

- [ ] **Step 5: Deploy and verify each host**

On each of `buzz`, `pricklepants` and `jessie`:

```bash
sudo nixos-rebuild switch --flake 'github:j340m3/nixos' --no-write-lock-file
systemctl is-enabled nixos-upgrade-health.service
systemctl is-active nixos-upgrade-health.timer 2>&1 | head -1   # expect: no such unit
sudo systemctl start nixos-upgrade-health.service; echo "exit=$?"
journalctl -u nixos-upgrade-health -n 5 --no-pager
```

Expected on each: the service is `enabled`, there is no `nixos-upgrade-health.timer`,
`exit=0` and `upgrade-health: no failed units, nothing to do` about five minutes after the
start. That gap is the settle delay; if the journal line appears instantly, the delay is
not wired in on that host.

- [ ] **Step 6: Watch one automatic upgrade cycle per host**

After the next hourly window has passed on each host:

```bash
journalctl -u nixos-upgrade-health --since "26 hours ago" --no-pager
journalctl -u nixos-upgrade --since "26 hours ago" --no-pager | tail -20
```

Expected: the health check logged the healthy line and `nixos-upgrade` completed. Confirm
the upgrade path actually ran the check, not only the boot path: the health check's
journal must show an entry roughly `settleDelay` *after* the `nixos-upgrade` entry from the
same cycle. If a rollback fired, the Telegram message names the unit that died and the
journal shows `nixos-rebuild rollback` running — that is the design working, and the unit
it names is the bug to fix next. A single rollback for a persistent failure, followed by
`already rolled back from this same set of failed units` on every later trigger, is the
guard working; a rollback and reboot every hour is the guard not working.
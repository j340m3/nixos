# Upgrade Health Check Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A headless NixOS host detects its own broken state (`systemd` reports failed units) after an upgrade or on boot, notifies over Telegram, and returns to the previous generation by itself.

**Architecture:** One new opt-in module, `modules/common/upgradeHealth.nix`, defines a timer bound to `switch-to-configuration.service` — which goes active on every boot *and* after every `nixos-rebuild switch` — plus a oneshot that checks `systemctl --failed` after a settle delay. On failure it fires the existing `notify-telegram@<unit>.service`, records the current generation in a guard file, then runs `nixos-rebuild rollback` and reboots. The guard file stops a rollback that did not help from repeating. Delivery is unchanged: floating lock, hourly autoUpgrade on `switch`.

**Tech Stack:** NixOS modules, systemd (timer, oneshot, `OnUnitActiveSec`), POSIX shell in a systemd `script`, sops-nix secrets (consumed via the existing notify unit).

**Spec:** `docs/superpowers/specs/2026-10-03-upgrade-health-auto-rollback-design.md`

**Testing note:** this repo has no test framework and this feature is systemd units, so the checkable result is the generated unit text plus live behavior on a real host. Every task therefore ends in an explicit command with the output that means it passed. Do not add a test harness for this.

## Global Constraints

- Delivery model does not change: `flake.lock` stays gitignored, `--no-write-lock-file` stays, `autoUpgrade` stays on `switch`, never `boot`.
- Enabled only on `mrpotatohead`, `buzz`, `pricklepants`, `jessie`, `bootstrap`. Never on `bootstrap-impermanent` (impermanence makes `/var/lib` tmpfs, so the guard file is lost every boot and the host could loop). Never on graphical hosts.
- Health signal is exactly the set of failed systemd units. No HTTP probes, no per-host probe lists, no health endpoints.
- Guard path is exactly `/var/lib/nixos-upgrade-health/rolled-back-from`, holding the output of `readlink /nix/var/nix/profiles/system` from the first rollback attempt on that generation.
- Every binary is referenced by absolute store path: `${pkgs.systemd}/bin/systemctl`, `${pkgs.coreutils}/bin/readlink`, `${pkgs.coreutils}/bin/install`, `${pkgs.nixos-rebuild}/bin/nixos-rebuild`. A unit's `PATH` is not a shell's; this repo has already shipped three units that failed on exactly this.
- `settleDelay` defaults to `"5min"` and is used as `OnUnitActiveSec`.
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
  - when enabled: `systemd.timers.nixos-upgrade-health` and `systemd.services.nixos-upgrade-health`
  - when disabled: neither unit exists at all, on any host

- [ ] **Step 1: Create `modules/common/upgradeHealth.nix`**

Module signature `{ config, lib, pkgs, ... }:`. `enable` is `lib.mkEnableOption "roll back the host when systemd reports failed units"`. `settleDelay` is `lib.types.str`, default `"5min"`, described as the wait between `switch-to-configuration.service` becoming active and judging the host.

Both units live under `config = lib.mkIf config.upgradeHealth.enable { ... }`. Timer: `wantedBy = [ "timers.target" ]`, `timerConfig = { Unit = "switch-to-configuration.service"; OnUnitActiveSec = config.upgradeHealth.settleDelay; AccuracySec = "1min"; Persistent = false; }`. Service: `Type = "oneshot"` via `serviceConfig`, no `wantedBy` (the timer starts it).

The `script`, verbatim:

```sh
guard=/var/lib/nixos-upgrade-health
${pkgs.coreutils}/bin/install -d -m 0755 "$guard"
failed=$(${pkgs.systemd}/bin/systemctl --failed --plain --no-legend)
if [ -z "$failed" ]; then
  echo "upgrade-health: no failed units, nothing to do"
  exit 0
fi
unit=$(printf '%s\n' "$failed" | ${pkgs.coreutils}/bin/head -n 1 | ${pkgs.coreutils}/bin/cut -d' ' -f1)
echo "upgrade-health: $unit failed, rolling back"
${pkgs.systemd}/bin/systemctl start --no-block "notify-telegram@$unit.service"
generation=$(${pkgs.coreutils}/bin/readlink /nix/var/nix/profiles/system)
if [ "$(cat "$guard/rolled-back-from" 2>/dev/null || true)" = "$generation" ]; then
  echo "upgrade-health: already rolled back from $generation, not rolling back again"
  exit 1
fi
printf '%s\n' "$generation" > "$guard/rolled-back-from"
${pkgs.nixos-rebuild}/bin/nixos-rebuild rollback
${pkgs.systemd}/bin/systemctl reboot
```

Decisions the script body fixes, so do not re-derive them:

- The spec says `systemctl --failed --quiet`. This script uses the list form instead, because one call then also yields the unit name, and `--quiet`'s exit code 1 for "nothing failed" would abort a `set -e` script.
- `--plain --no-legend` is what keeps `head -n 1 | cut -d' ' -f1` returning a verbatim unit name.
- The guard read tolerates a missing file (`|| true`) so the first run cannot abort under `set -e`.
- Notification is started before the guard check and without `--no-block` omitted, so a slow or failing Telegram call cannot delay or block the rollback.
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
       timerExists = c.systemd.timers ? nixos-upgrade-health;
       serviceExists = c.systemd.services ? nixos-upgrade-health; }'
```

Expected: `{"enable":false,"settleDelay":"5min","timerExists":false,"serviceExists":false}`. This is what pins Review Focus item 5: `settleDelay` resolves through the option, so a host can raise it.

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
- Produces: on `mrpotatohead` only, `nixos-upgrade-health.timer` is active and its script is verified against Review Focus items 1-4.

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

- [ ] **Step 3: Inspect the generated script and timer**

```bash
nix eval --impure --json --expr '
  let c = (builtins.getFlake "git+file:///home/jeromeb/code/github/nixos").nixosConfigurations.mrpotatohead.config;
  in { script = c.systemd.services.nixos-upgrade-health.script;
       timer = c.systemd.timers.nixos-upgrade-health.timerConfig; }' | python3 -m json.tool
```

Expected: `timer` contains `"Unit": "switch-to-configuration.service"` and `"OnUnitActiveSec": "5min"`. In `script`, every occurrence of `systemctl`, `readlink`, `install`, `nixos-rebuild` must be preceded by `/nix/store/`. If any is bare, stop and fix Task 1's script before continuing.

- [ ] **Step 4: Commit and push**

```bash
git add hosts/headless/mrpotatohead/default.nix
git commit -m "Enable the upgrade health check on mrpotatohead"
git push
```

- [ ] **Step 5: Deploy and prove the healthy path on the live host**

```bash
sudo nixos-rebuild switch --flake 'github:j340m3/nixos' --no-write-lock-file
systemctl list-timers nixos-upgrade-health.timer --no-pager
sudo systemctl start nixos-upgrade-health.service
echo "exit=$?"
```

Expected: the timer is listed with `NEXT` roughly 5 minutes out; `systemctl start` returns `exit=0`; `journalctl -u nixos-upgrade-health -n 5` shows `upgrade-health: no failed units, nothing to do`. Record the boot time before continuing:

```bash
who -b
```

- [ ] **Step 6: Prove the unhealthy path without letting it roll back**

Pre-seed the guard with the current generation, which is exactly what makes the script take the "already rolled back" branch and stop before `nixos-rebuild rollback`:

```bash
sudo mkdir -p /var/lib/nixos-upgrade-health
readlink /nix/var/nix/profiles/system | sudo tee /var/lib/nixos-upgrade-health/rolled-back-from
sudo systemd-run --unit=health-test-fail.service --property=Type=oneshot /bin/false
sleep 2
systemctl --failed --plain --no-legend
sudo systemctl start nixos-upgrade-health.service; echo "exit=$?"
journalctl -u nixos-upgrade-health -n 10 --no-pager
systemctl status "notify-telegram@health-test-fail.service" --no-pager | head -5
who -b
```

Expected, and this is what pins Review Focus items 1, 3 and 4:

- `systemctl --failed --plain --no-legend` lists `health-test-fail.service` and no `\x2d` escaping.
- The journal shows `upgrade-health: health-test-fail.service failed, rolling back`, then `upgrade-health: already rolled back from /nix/var/nix/profiles/system-<n>-link, not rolling back again`.
- `exit=1`.
- A Telegram message arrived naming `health-test-fail.service` with its exit code and journal line.
- `who -b` is unchanged: **no reboot happened**.
- Re-running the check does not create a second message or another attempt.

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
- Modify: `hosts/headless/bootstrap/default.nix`

**Interfaces:**
- Consumes: `upgradeHealth.enable` from Task 1.
- Produces: the option enabled on all five intended headless hosts, none on graphical hosts or `bootstrap-impermanent`.

- [ ] **Step 1: Enable the option on the four remaining hosts**

Add this line to each of the four files above, at the same nesting level as in Task 2:

```nix
upgradeHealth.enable = true;
```

- [ ] **Step 2: Format and evaluate everything**

```bash
cd /home/jeromeb/code/github/nixos
nixfmt hosts/headless/{buzz,pricklepants,jessie,bootstrap}/default.nix
for h in buzz pricklepants jessie bootstrap woody rex sid slinky lenny zurg bootstrap-impermanent; do
  printf '%-22s ' "$h"
  nix eval --no-write-lock-file --raw ".#nixosConfigurations.$h.config.system.build.toplevel.drvPath" >/dev/null \
    && echo OK || echo FAIL
done
```

Expected: `OK` for all 11.

- [ ] **Step 3: Confirm the enabled set is exactly the intended five**

```bash
nix eval --impure --json --expr '
  let f = builtins.getFlake "git+file:///home/jeromeb/code/github/nixos";
  in builtins.mapAttrs (_: c: c.upgradeHealth.enable) f.nixosConfigurations'
```

Expected: `buzz`, `pricklepants`, `jessie`, `mrpotatohead`, `bootstrap` are `true`; every graphical host and `bootstrap-impermanent` are `false`. If `bootstrap-impermanent` is `true`, stop: its tmpfs root makes the guard file vanish every boot.

Then confirm no enabled host can lose its rollback target, which the spec requires:

```bash
nix eval --impure --json --expr '
  let f = builtins.getFlake "git+file:///home/jeromeb/code/github/nixos";
  in builtins.mapAttrs (_: c: if c.upgradeHealth.enable then c.boot.loader.grub.configurationLimit else null)
       f.nixosConfigurations'
```

Expected: for the five enabled hosts, no value is `1`. `pricklepants` is already `2`, which is the tightest acceptable value; the others inherit the NixOS default of `100`. A `1` means that host can never roll back and the option must be raised there.

- [ ] **Step 4: Commit and push**

```bash
git add hosts/headless/{buzz,pricklepants,jessie,bootstrap}/default.nix
git commit -m "Enable the upgrade health check on the remaining headless hosts"
git push
```

- [ ] **Step 5: Deploy and verify each host**

On each of `buzz`, `pricklepants`, `jessie`, then `bootstrap` last:

```bash
sudo nixos-rebuild switch --flake 'github:j340m3/nixos' --no-write-lock-file
systemctl list-timers nixos-upgrade-health.timer --no-pager
sudo systemctl start nixos-upgrade-health.service; echo "exit=$?"
journalctl -u nixos-upgrade-health -n 5 --no-pager
```

Expected on each: `exit=0` and `upgrade-health: no failed units, nothing to do`.

- [ ] **Step 6: Watch one automatic upgrade cycle per host**

After the next hourly window has passed on each host:

```bash
journalctl -u nixos-upgrade-health --since "26 hours ago" --no-pager
journalctl -u nixos-upgrade --since "26 hours ago" --no-pager | tail -20
```

Expected: the health check logged the healthy line and `nixos-upgrade` completed. If a rollback fired, the Telegram message names the unit that died and the journal shows `nixos-rebuild rollback` running — that is the design working, and the unit it names is the bug to fix next.
# Immich move to headless VPS (filen live + Borg NAS backup) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Immich from woody to a headless VPS with live media on filen (rclone), reachable only via VPN, and versioned Borg backups from woody to old NAS. NAS becomes backup-only.

**Architecture:** Keep live storage on filen (rclone) because VPS disk is limited; use rclone VFS cache on VPS root FS. Migrate NAS→filen via rclone (remote-to-remote or staged on woody spare disk). Dump/restore Immich Postgres from woody to VPS over Nebula. Cutover to VPS (single writer). Woody runs Borg to snapshot filen media (read-only mount) and DB dumps to NAS Borg repo with prune policy. Follow repo's rclone naming convention matching Nextcloud.

**Tech Stack:** NixOS, Immich (services.immich), rclone, BorgBackup, PostgreSQL, Nebula (VPN), systemd timers.

**Spec:** /home/jeromeb/Dokumente/code/nixos/docs/superpowers/specs/2025-10-13-immich-move-to-vps-design.md

## Global Constraints
- VPN-only access (listen on VPN interface only; no public ports).
- Follow repo's rclone naming convention matching Nextcloud (inspect modules/configs and mirror for Immich/filen).
- Live media on filen via rclone (RW) on VPS; VPS root FS for rclone VFS cache (size conservatively).
- NAS backup-only; written by woody only via Borg (versioned, incremental, dedup+compressed). Avoid destructive rclone sync/mirror.
- Single writer: only VPS runs Immich after cutover; woody Immich stopped before cutover.
- Keep rclone for filen live mount, migration, existing configs.
- Incremental backups to NAS with history (point-in-time restore).
- Secrets handled via existing repo pattern (sops/agenix/vaultix) if present.

## Review Focus
- **Single-writer enforcement**: Starting both Immich instances must be impossible in deployed config (only one enabled). Expect correct cutover.
- **Deletion safety**: NAS backup must not propagate deletions from filen (Borg history preserved; no rclone sync/mirror). Expect recoverable snapshots.
- **Cache pressure**: rclone VFS cache on VPS root FS must not fill disk (conservative limit, min-free-space). Expect stable mount.
- **Migration consistency**: NAS→filen transfer uses checksums; DB dump restored before starting VPS Immich. Expect consistent library state.
- **VPN-only boundary**: Immich binds to VPN IP only, public ports closed. Expect unreachable off-VPN.

---

### Task 1: Inspect Nextcloud rclone naming and define Immich/filen naming
**Files:**
- Read: `modules/nextcloud*.nix`, `modules/common/*rclone*`, any `rclone*.conf` or rclone-related Nix in repo (discover via glob/grep)

**Interfaces:**
- Consumes: repo conventions
- Produces: naming rule (remote names, config filenames, mount unit names) to use for Immich/filen

- [ ] **Step 1: Discover nextcloud rclone pattern**
  - Run: `grep -rn "rclone" /home/jeromeb/Dokumente/code/nixos/modules/nextcloud* 2>&1 | head -30`
  - Run: `grep -rn "filen\|rclone.*conf\|remote" /home/jeromeb/Dokumente/code/nixos/modules | head -30`

- [ ] **Step 2: Extract exact naming**
  - Record: remote name(s), config path(s) (e.g. `/etc/rclone-*.conf`), mount service/unit names, secrets handling.

- [ ] **Step 3: Define Immich/filen naming to mirror**
  - Document: proposed remote (e.g. `filen-immich`), config file naming matching pattern, mount unit naming consistent, Nix module placement.

- [ ] **Step 4: Commit (if doc added)**
  - Add decision note to plan context if needed.

---

### Task 2: Prepare remotes and targets (woody + VPS)
**Files:**
- Modify (woody): existing rclone config(s) to include filen remote for immich (follow naming). 
- Modify (VPS): ensure rclone config present with filen-only access as per secrets pattern.
- Create dirs: `/mnt/immich` on VPS (mount point), cache dir `/var/cache/rclone` sizing note.

**Interfaces:**
- Consumes: Task 1 naming
- Produces: both remotes available (woody has nas+filen; VPS has filen), target paths created.

- [ ] **Step 1: Add filen remote to woody rclone config (preserve existing)**
  - Edit woody `/etc/rclone*.conf` (or Nix-managed) to add filen remote named per Task 1. Never overwrite existing remotes.

- [ ] **Step 2: Create filen target path**
  - `rclone mkdir filen-immich:immich --config <woody-config>` (per naming)

- [ ] **Step 3: Prepare VPS rclone config (filen-only) + dirs**
  - Ensure VPS has filen remote in its rclone config (secrets). Create `/mnt/immich` and ensure `/var/cache/rclone` exists with ownership for immich.

- [ ] **Step 4: Test connectivity (RO)**
  - `rclone lsd filen-immich:immich --config <woody-config>` succeeds. Same from VPS.

- [ ] **Step 5: Commit Nix changes**
  - `git add modules/... && git commit -m "chore(rclone): add filen remote for immich per nextcloud naming"`

---

### Task 3: Quiesce woody and dump Postgres
**Files:**
- Modify: woody Nix/service state (stop immich)
- Create: DB dump file (timestamped)

**Interfaces:**
- Consumes: current woody immich state
- Produces: consistent DB snapshot ready to restore on VPS

- [ ] **Step 1: Stop immich on woody**
  - `systemctl stop immich-server immich-machine-learning`. Verify stopped.

- [ ] **Step 2: Create DB dump**
  - Use `pg_dump -Fc` for immich DB. Save to `/var/tmp/immich-db-$(date +%F_%H-%M-%S).dump`.

- [ ] **Step 3: Transfer dump to VPS over Nebula**
  - `rsync -az /var/tmp/immich-db-*.dump immich@<vps-nebula-ip>:/var/tmp/`

- [ ] **Step 4: Commit (log/ops note)**
  - `git commit --allow-empty -m "ops(immich): quiesce woody and dump db for cutover"`

---

### Task 4: Migrate media NAS → filen (remote-to-remote or staged)
**Files:**
- Operational transfer

**Interfaces:**
- Consumes: quiesced state (Task 3), remotes (Task 2)
- Produces: full media on filen verified by checksums/sizes

- [ ] **Step 1: Choose path (remote-to-remote preferred)**
  - If spare disk present and remote-to-remote slow/flaky: stage; else remote-to-remote. Record choice.

- [ ] **Step 2: Run migration with checksums**
  - Remote-to-remote: `rclone copy --checksum --create-empty-src-dirs nas:immich filen-immich:immich --config <woody-config>`
  - Staged: `rclone copy nas:immich /path/to/spare/immich-stage && rclone copy /path/to/spare/immich-stage filen-immich:immich`

- [ ] **Step 3: Verify integrity**
  - Compare sizes: `rclone size nas:immich` and `rclone size filen-immich:immich`. Spot-check if desired.

- [ ] **Step 4: Commit (log)**
  - `git commit --allow-empty -m "ops(immich): migrated nas->filen (checksummed)"`

---

### Task 5: Configure Immich on VPS to use filen (rclone mount)
**Files:**
- Modify: VPS Nix module(s) for immich. Add rclone mount to filen with VFS cache on root FS, tuned for limited disk.
- Ensure firewall allows only VPN CIDR on 2283; bind to VPN interface only.

**Interfaces:**
- Consumes: naming (Task 1), remotes (Task 2)
- Produces: working rclone mount for filen on VPS; immich points to mount.

- [ ] **Step 1: Add rclone mount for filen in NixOS**
  - Mirror existing immich mount style (type rclone). Use filen remote name, config path per naming, `mediaLocation = "/mnt/immich"`. 
  - Cache: `cache_dir=/var/cache/rclone`, `vfs-cache-mode=full`, `vfs-cache-max-age=24h`, `vfs-cache-min-free-space` (conservative, >=5–10GB), tuned chunk sizes. Run as immich uid/gid.
  - Dependencies: `x-systemd.requires=network-online.target`, `x-systemd.after=network-online.target`. Ensure `systemd.services.immich-server.after = ["mnt-immich-filen.mount"]`.

- [ ] **Step 2: Harden networking (VPN-only)**
  - Bind immich to VPN IP/interface (Nebula). Allow 2283 from VPN CIDR only; block public. Mirror Nebula allowlist pattern.

- [ ] **Step 3: Restore DB on VPS and start Postgres/Redis**
  - Restore: `pg_restore -d immich --clean --if-exists /var/tmp/immich-db-*.dump`. Ensure Postgres/Redis running.

- [ ] **Step 4: Enable/configure immich on VPS (stopped initially)**
  - Set `services.immich.enable = true`, point to restored DB, mediaLocation to filen mount. Do not start until mount verified.

- [ ] **Step 5: Test mount RW/RO**
  - Start mount, verify read/write as immich user context.

- [ ] **Step 6: Commit Nix changes**
  - `git add modules/... hosts/... && git commit -m "feat(immich): add filen rclone mount on VPS and vpn-only binding"`

---

### Task 6: Cutover to VPS (single writer)
**Files:**
- Nix/service state changes

**Interfaces:**
- Consumes: Task 5 ready
- Produces: Immich live on VPS only

- [ ] **Step 1: Ensure woody still stopped**
  - `systemctl status immich-server` on woody → inactive.

- [ ] **Step 2: Start immich on VPS**
  - `systemctl start immich-server immich-machine-learning`. Check logs.

- [ ] **Step 3: Smoke test over VPN**
  - Login, browse, thumbnails, upload/download, search, jobs.

- [ ] **Step 4: Enforce single-writer (config)**
  - Keep woody immich disabled/stopped; VPS enabled.

- [ ] **Step 5: Commit**
  - `git commit --allow-empty -m "ops(immich): cutover to vps (filen mount, single-writer)"`

---

### Task 7: Setup Borg backups from woody to NAS (filen→NAS, versioned)
**Files:**
- Borg repo init, systemd service + timer on woody

**Interfaces:**
- Consumes: NAS mount on woody, filen RO access from woody, DB dumps location
- Produces: scheduled versioned backups to `/mnt/nas/borg/immich/`

- [ ] **Step 1: Prepare NAS mount access on woody**
  - Ensure woody can write to NAS. Create borg dir: `mkdir -p /mnt/nas/borg/immich`.

- [ ] **Step 2: Init Borg repo (LAN-only)**
  - `borg init --encryption=none /mnt/nas/borg/immich`.

- [ ] **Step 3: Mount filen read-only on woody for backup**
  - Add rclone mount for filen RO on woody (separate unit), separate mount point (e.g. `/mnt/filen-immich-ro`). No RW.

- [ ] **Step 4: Create systemd service for backup**
  - Service: mount RO, backup media path + DB dumps to Borg repo (`borg create ::{now:%Y-%m-%d_%H-%M-%S}`). Include prune: `borg prune --keep-daily=7 --keep-weekly=4 --keep-monthly=6 /mnt/nas/borg/immich`.

- [ ] **Step 5: Create systemd timer**
  - Daily timer, persistent. Enable.

- [ ] **Step 6: Test manually**
  - Run service, verify `borg list` shows archive, restore dry-run works.

- [ ] **Step 7: Commit Nix/systemd changes**
  - `git add modules/... systemd/... && git commit -m "feat(backup): borg incremental backups immich filen->nas on woody"`

---

### Task 8: Final verification & hardening
**Files:**
- Config tweaks if needed

**Interfaces:**
- Consumes: all tasks
- Produces: verified migration

- [ ] **Step 1: Verify single-writer**
  - Only VPS immich enabled; woody disabled.

- [ ] **Step 2: Verify VPN-only**
  - Off-VPN unreachable, on-VPN reachable on 2283.

- [ ] **Step 3: Verify backups**
  - `borg list /mnt/nas/borg/immich` recent archives; prune applied; small file restore dry-run passes.

- [ ] **Step 4: Monitor cache**
  - `/var/cache/rclone` < limit, min-free-space enforced.

- [ ] **Step 5: Commit**
  - `git commit --allow-empty -m "docs(ops): verify immich migration to vps with borg nas backups"`
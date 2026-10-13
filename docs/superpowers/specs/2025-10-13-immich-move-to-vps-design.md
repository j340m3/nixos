# Design: Move Immich from Woody to Headless VPS with filen storage + NAS backups

## Status
- **Type**: Architectural
- **Path**: brainstorming completed, approved
- **Date**: 2025-10-13

## Problem statement recap
Move Immich from woody to a headless VPS. Immich should be accessible via VPN only. Storage is an rclone-mounted drive (filen). A copy of the rclone drive should be written by woody to the NAS (backups). NAS is old, LAN-only (same network as woody), cannot reach VPS. VPS disk limited. Keep existing rclone configs naming consistent with Nextcloud in this repo. Prefer Borg for NAS backups (versioned, incremental, safe against deletion propagation). Use rclone for live filen mount.

## Solution summary
- Move Immich app to headless VPS, listen only on VPN interface (Nebula). No public exposure.
- Live media root on **filen** via rclone mount (RW) on VPS (VPS disk limited, use `/var/cache/rclone` on root FS).
- Migrate: remote-to-remote `rclone copy nas:immich filen:immich` on woody (with optional local staging on woody spare disk). Also dump/restore Immich Postgres from woody to VPS over Nebula.
- NAS becomes **backup-only**. Woody runs **Borg** to create versioned incremental snapshots of filen media (read-only mount) to NAS repo (`/mnt/nas/borg/immich/`). DB dumps backed up to NAS/Borg separately. Use `rclone copy --update` only as fallback, not mirror.
- Single writer: only VPS runs Immich after cutover. Woody Immich stopped before migration/cutover.

## Key requirements
- VPN-only access
- Follow repo's rclone naming convention (match Nextcloud)
- Borg for NAS backups (incremental, versioned, dedup+compression). Avoid destructive sync/mirror.
- rclone kept for filen live mount + migration + existing configs
- Incremental backups to NAS; preserve history (point-in-time restore)
- VPS root FS used for rclone cache (size conservatively)

## Implementation outline
1. Inspect nextcloud rclone naming in repo (modules/configs) to mirror for Immich (filen).
2. Prepare filen target path and ensure both remotes (nas, filen) on woody; filen-only on VPS.
3. Quiesce woody Immich → DB dump → NAS→filen migration (remote-to-remote or staged) with checksum.
4. Restore DB on VPS → configure Immich on VPS with rclone mount to filen (NixOS), mediaLocation to mount point, cache sized/tuned.
5. Cutover: stop woody, start VPS, smoke test over VPN. Verify single writer.
6. Setup Borg repo on NAS, systemd timers on woody to backup filen (RO) + DB dumps to NAS/Borg with prune policy.
7. Harden (VPN-only firewall, secrets via sops/agenix if present, mount deps, cache limits).

See full details in brainstorming discussion above.
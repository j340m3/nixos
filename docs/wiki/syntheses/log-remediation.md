# Fleet log-remediation sweep — 2026-11-03

Evidence source: woody `/persist/rsyslog/<host>/` (loghost cutover, pass 5).
All fixes pushed to origin/main the same day; nothing here needs an ADR
(see session grilling Q14). Status vocabulary: **fixed** (verified live),
**deployed** (fix on main, host not yet rebuilt/verified), **open** (needs
user/on-host follow-up).

## Issue ledger

| # | Symptom (observed) | Root cause | Fix | Status |
|---|---|---|---|---|
| 1 | pricklepants minetest-server crash-looped; 38k `ModError` lines in current log | stale 2026 VoxeLibre game copy discovered by luanti 5.17 | commit 1baad0d pins `LUANTI_GAME_PATH=...voxelibre-game-0.92.3`, preStart parks stale dir | **fixed** — live generation verified 2026-11-03, 0 ModError / 0 restarts since switch, only benign lag warnings |
| 2 | all three mesh borg jobs starved: minecraft-bedrock repo empty (created 2025-07-08, never an archive), minetest/pricklepants repos stale | endlessh tarpit owns woody `:22` since 2026-10-27 (ssh hardening aspect); clients dialed default port and hung | commit 23475e8: `-p ${constants.sshPort}` on all three `BORG_RSH` | **deployed** — verify after next nightly runs (02:30 / daily) |
| 3 | jessie `minecraft-bedrock` job EROFS on `/run/lock/netavark.lock`; pricklepants+minetest jobs abort nightly at non-interactive `unknown unencrypted repository` prompt | borgbackup module hardening (`ProtectSystem=strict`) keeps `/run` RO beyond its own dirs; ephemeral borg caches drop the repo security stamp | e60f0bf: `/run/lock` ReadWritePaths + `BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK`/`BORG_RELOCATED_REPO_ACCESS_IS_OK` on both jobs (mesh-local family backups) | **deployed** |
| 4 | woody NM wifi profile broke when the SSID pre-shared key left the plain `wifi.nix` roster symlink/dotenv layer | NetworkManager ensureProfiles needed an env-file indirection | 454c3ff: `nm-wifi-env` service writes `/run/nm-wifi.env`, `environmentFiles = [ /run/nm-wifi.env ]` | **fixed** — verified live: `UPC5171371:wlp0s20f3:activated` in today's generation |
| 5 | woody immich-ml unit retried HOME inside a RO sandbox path | machine-learning unit needs a writable HOME | 454c3ff: `HOME=/var/lib/immich-ml` via StateDirectory | **fixed** — verified live: unit active with the new HOME in today's generation |
| 6 | mrpotatohead audit.log flooded (54k `auid=4294967295`, tens/day by uid 996/989) | audit rules only had broad SERVICE_START/STOP without exclusions | c4ed4ac: never-rules narrowed for uid=996/989 | **deployed, verified inbound** — potato's hourly upgrades picked it up: `uid=996/989` lines 0 in today's audit.log; generic `auid=4294967295` service noise (~10k/day) remains by design |
| 7 | mrpotatohead unreachable: woody logged **20339** `Handshake timed out vpnAddrs=[10.0.0.6] udpAddrs=[]` (current log since 2026-11-01 00:04); same pattern in history back to ≥2025-07 | potato's lighthouse endpoints in `modules/global/_constants.nix` (`85.214.10.114`, `[2a01:239:4ac:7300::1]`):4242 do not answer; every host's staticHostMap inherits the stale pair | none yet — needs on-host inspection | **open** (user action 1). Paradox recorded: potato logs still stream into woody live (TCP 514 via something ss doesn't show e.g. journald-relay or flappy tunnel), but `ping 10.0.0.6` = 100% loss, ssh/nebula handshake dead ⇒ ssh-only audit-rule verification impossible |
| 8 | pricklepants vaultwarden hourly `GET /api/sync` → `Failed to decode refresh_token from <IP>: Token has expired` spam | a **roaming portable client** (Telekom IPs: 80.187.x LTE ↔ 92.209.155.230 DSL) polling hourly with an expired refresh token; server-side rbw on woody syncs 200 OK | none needed server-side | **open** (user action 2: re-login that device) |
| 9 | silent backups were invisible for months (repo #2 unchecked since 2025-07) | no staleness monitoring; only onFailure paged | 454c3ff: new `modules/services/log-watchdog.nix` aspect: daily staleness check over `/persist/rsyslog`, 48h threshold, telegram pager via sops secrets; monitors woody/jessie/mrpotatohead/pricklepants, `expectedOff` = lenny/rex/slinky/buzz | **deployed** (woody) |
| 10 | fleet coverage matrix frozen: lenny silent since 2025-08-26, rex since 2025-09-05, slinky since 2025-09-04, buzz‬ offline-but-odd (60/60 empty files while holding live TCP 514/42069 sessions to woody) | parked by decision (Q10/Q11): buzz/lenny/rex/slinky are `expectedOff`; sid/zurg coverage is a `TODO` comment in `modules/services/logging.nix` | watchdog makes re-appearances visible | **parked** |

## User actions (no sudo available this session)

1. **mrpotatohead on-host inspection** (unblocks #6 verification + #7):
   on potato paste the output of
   ```
   ip -brief addr show; ip route show
   sudo systemctl status nebula@mesh --no-pager -n 50
   sudo ss -tnup | grep -E '514|4242'
   ```
   Then update `host.mrpotatohead.endpoints` in `modules/global/_constants.nix`
   (potato is a lighthouse; every peer inherits the negative cache until this is right).
2. **Vaultwarden**: on the commuting laptop/phone that polls hourly (Telekom APN / DSL peak),
   sign out + back in → the `Failed to decode refresh_token` spam stops.
3. **Sudo cleanup on woody** (attended):
   ```bash
   # legacy dynafile dirs that pre-date host-name templates (pricklepants' old src IP, localhost spam)
   sudo rm -rf /persist/rsyslog/10.0.0.1 /persist/rsyslog/127.0.0.1
   # empty stub files of expected-off hosts (recreated on their next real message)
   sudo find /persist/rsyslog/{lenny,rex,slinky,buzz} -name '*.log' -size 0 -delete
   ```

## Verification plan

- **Tonight**: jessie `minecraft-bedrock` job 02:30 → `ls -la woody:/var/lib/borgbackup/minecraft-bedrock/`
  should leave the 2025-07-08 mtime; minetest/pricklepants jobs at daily → repo dirs
  should get fresh `hints.*`/`index.*` + archives. Telegram stays silent on success.
- **Potato**: once SSHable again (`ssh -p 42069 donquezz@10.0.0.6`), confirm
  `readlink /run/current-system` contains the audit never-rules generation and
  `audit.log` day-counts drop from ~10k.
- **Wifi + immich-ml on woody**: verified live 2026-11-03 (wifi profile
  activated via the dotenv env service, ML unit active with the new writable HOME).
- **Watchdog**: next daily run sends a Telegram heartbeat/failure message listing any
  of the 4 monitored hosts >48h silent — expected one listing mrpotatohead? (no:
  48h threshold vs its live log flow ⇒ watch for a *false* alert if #7's transport
  silently degrades further).

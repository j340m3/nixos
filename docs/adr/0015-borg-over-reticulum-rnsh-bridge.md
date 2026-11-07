# ADR-0015: Migrate borg backup transport to reticulum (dedicated rnsh-borg bridge)

**Date**: 2026-11-07
**Status**: accepted
**Deciders**: jeromeb + reticulum-transport grilling session
**Knowledge**: docs/wiki/ (Reticulum thread, syntheses/pricklepants-transport-node.md)

## Context

Borg clients (pricklepants `/etc`+vaultwarden job, plus minetest on pricklepants
and minecraft-bedrock on jessie) reach woody's repos over SSH through the nebula
mesh (`repo = "borg@${woody.ip}:..."`, accept side in
`modules/services/borg-server.nix`). Nebula has been the less reliable leg this
year (identity repair, crash loops, key rotations), LAN jobs currently hairpin
through the lighthouses, and more backup targets are planned — so the mesh-vetted
reticulum overlay (fleet-wide since the ssh shim landed) becomes the *primary*
transport.

The reticulum side already proves binary-clean stdio: `rnsh-nix.service`
carries `nix-daemon --stdio` over rnsh (fleet-wide distributed builds and
substituters dial `${h}-rns` through the same shim). Three hard problems had to
be solved to open that path to borg:

1. **`rnsh` has no application-name option** (APP_NAME is hardwired to
   `"rnsh"`), so a *second* listener on a host needs its *own RNS identity* to
   get a distinct destination hash.
2. **`rnsh-nix` ran as root**, spawning the unwrapped nix daemon — any fleet
   RNS identity gets a root session. Unacceptable regardless of borg.
3. **The ssh shim** hard-matches any arg ending `-rns` and always prints the
   nix "started" handshake marker — borg speaks bare stdio and would break, and
   its repo string `borg@woody-borg-rns:repo` never *ends* in `-rns` anyway.

## Decision

1. **RNS is the primary transport for borg; nebula stays as rollback** (one-line
   repo-string revert via the untouched sshd accept side), not an automatic
   fallback: failures must stay loud (telegram notify-telegram wiring) so RNS
   reliability data is not masked by silent fallback.
2. **Dedicated `rnsh-borg` listener on woody** (`modules/system/reticulum.nix`,
   behind `services.reticulum.rnshBorg`): its own sops-protected RNS identity
   (`reticulum/borg_identity`), runs as the existing `borg` user, and executes
   the same forced command the sshd path yields:
   `borg serve --append-only --restrict-to-path /var/lib/borgbackup`. Auth is an
   RNS identity allowlist (phase 1: pricklepants only), *not* a shared blanket
   allowlist.
3. **Not the nix bridge**: backup traffic never touches `rnsh-nix` (different
   identity, different destination, different allowlist, different user).
4. **Root-broker fix (fleet-wide, not borg-specific)**: `rnsh-nix` now runs as
   `remotebuild` and spawns the same store `nix-daemon` the nebula ssh-ng chain
   runs (`remotebuild ∈ nixbld` for store writes). Identity allowlist plays the
   authorized_keys role; the unprivileged account is the factor between peer and
   build machinery. Per-service allowlists are decisions per listener: borg =
   backup clients, nix = whole fleet (every host is a build peer within
   `maxJobs`).
5. **Shim generalization** (keeps nix byte-compatible, hosts borg):
   `-rns` matching handles `user@host:path` repo strings; the `started` marker
   prints only when a remote *command* follows the host arg (nix semantics,
   `/nix/source/libstore/ssh.cc`) — borg, interactive ssh and `-O check`
   behaviour stay as they were.
6. **Non-root listeners read root's reticulum state**: group `reticulum`
   (`services.reticulum.identityReaders` = the users) grants 0440 reads of the
   decoded identity and a minimal config view `/var/lib/reticulum-share`
   (0750, symlinking the real config); listeners attach to the root shared
   instance over its abstract UNIX socket (`@rns/default`). Root's 0700 identity
   storage stays unreadable — no identity-file leak to listeners.
7. **Client side first nicety**: the disabled-encryption surprise guards
   (`BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK`,
   `BORG_RELOCATED_REPO_ACCESS_IS_OK`) are NOT permanently set. The pricklepants
   repo id is already in the client security cache, so the relocated guard trips
   once at the trial run; one manual run with the env var updates the cached
   location, and daily surprises stay loud afterwards.

## Alternatives considered

- **Shim fallback logic** (try RNS, fall back to nebula on failure): rejected —
  masks RNS weakness in the data we are collecting; woody-side fallback only if a
  week of daily evidence demands it.
- **Reuse the root nix bridge/add an app aspect to rnsh**: rnsh can't take an
  APP_NAME, so it would have meant sharing the *root*-privileged nix listener —
  root factor violated.
- **Grant listeners read on /var/lib/reticulum**: exposes the fleet identity
  files in RNS `storage/`; the symlink-view dir keeps the exposure at the config
  and the specific listener identity only.

## Consequences

- `constants.reticulum.identities.woody.borg` = destination hash of the borg
  listener; `woody-borg-rns` entry in `/etc/reticulum/ssh-hosts` generated from
  it (fleet-wide file, harmless elsewhere).
- pricklepants job switched to `borg@woody-borg-rns:pricklepants`; `BORG_RSH`
  keeps the sops key for rollback (shim drops `-i`/`-p`).
- Phase 1 = pricklepants only; a manual trial must succeed, stay under ~30 min
  and within the 1 GB box's memory ceilings before the daily job flips; LAN
  locality (AutoInterface) is phase 2 (jessie's minecraft job first).
- `remotebuild` gained `nixbld` — representative of what the ssh-ng path already
  required; nothing else changed for nebula-side builders.
- Accept-side sshd repos (nixpkgs module) remain for rollback; `borg-prune`
  timer unchanged.
- Known RNS caveats carried from the vault thread: listen backlog / single
  announce thread and RNS < nebula throughput — the trial's 30-minute gate and
  the 1 GB memory ceiling check exist for exactly those.

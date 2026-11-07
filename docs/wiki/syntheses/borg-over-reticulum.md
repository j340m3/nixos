# Synthesis: borg over reticulum (the rnsh-borg bridge)

Decision record: [ADR-0015](../../adr/0015-borg-over-reticulum-rnsh-bridge.md). Complements the [pricklepants transport-node synthesis](pricklepants-transport-node.md) with an *application* question: can the borg fleet move from nebula+SSH to the RNS overlay?

**Verdict:** yes — but through a dedicated bridge identity, never through the root nix daemon. Three constraints shaped the design:

1. `rnsh` hardwires APP_NAME = "rnsh" (`rnsh.py`), so a host cannot run two differently-named listeners on one identity: the borg listener needs its **own RNS identity** (separate sops secret on woody), which yields a distinct destination hash that the ssh shim maps as `woody-borg-rns`.
2. The same listener pattern that carried `nix-daemon --stdio` was root-to-root, so it could **not** be reused for borg — and became unprivileged itself in the process (the `remotebuild` + nixbld fix is the generic expression of "no rnsh service hands out root").
3. The ssh shim's contract is nix-specific (matches `*-rns` word-endings and always answers the `LocalCommand="echo started"` handshake expected by `libstore/ssh.cc`). Borg speaks bare stdio, so the shim now conditionally prints `started` only when a remote command follows the host arg, and resolves `user@host:path` repo strings against `/etc/reticulum/ssh-hosts`.

## Why RNS as primary, SSH as rollback

RNS has been the *more reliable* leg (nebula had identity repair, crash loops, key rotations this year) and unlocks traffic-locality for future LAN backup targets via AutoInterface. Reliability claims must stay **falsifiable**: no shim-side fallback — failures page telegram; fallback (if ever) is a woody-side decision after a week of daily evidence. Borg's missing-encryption surprise guards are also not pre-tuned: the client's relocated-repo guard trips *once* at the trial connection, gets its cache updated by that one manual run, and every later surprise stays loud.

## Accept-side contract

`rnsh-borg.service` on woody mirrors `rnsh-nix` exactly except user/allowlist/binary and the `Home`/`ArgsExtra` flags (`services.reticulum.rnshBorg`):

- **identity**: own listener identity (`reticulum/borg_identity` sops key) → `identities.woody.borg` = `067d1f1ca78f19cd1c42ff9e3f19e1a9` (checked every unit start with the same rnid gate);
- **user**: existing `borg` user from the nixpkgs borgbackup repo side, `WorkingDirectory` + `restrict-to-path /var/lib/borgbackup`, `--append-only` always: client deletion is impossible by construction; pruning stays the root-owned `borg-prune` timer;
- **allowlist**: `rnsh -a` = one hash per *migrating client* (phase 1: pricklepants only), not a fleet blanket — allowlists are per-service decisions;
- **stdin/out:** binary clean end-to-end (proven by the nix bridge), the rnsh streaming-initiator patch that avoids whole-stdin buffering is inherited.

## How non-root listeners reach root's reticulum state

The shared instance speaks the `@rns/default` abstract UNIX socket — any local user can connect — but the *filesystem* state must not leak: a group `reticulum` grants 0440 reads of `/run/reticulum/identity` (fleet identity: it *is* the authenticated-listener key) and a minimal `config` symlink view in root-owned `/var/lib/reticulum-share` (0750). Root's 0700 `/var/lib/reticulum` holding the fleet identity's RNS `storage/` files (including its key material) stays closed — granting *that* would hand every listener user the ability to mint fleet identities.

## Rollout gates

1. decrypt-time sops secret on woody (`borg_identity` as URL-safe base64 — verify with `rnid -i` decode gate before accepting it).
2. Listener identity-trial: manual borg run (client has the fresh location hash), success under ~30 min, memory within the 1 GB pricklepants ceilings.
3. Daily for a green week before more jobs migrate; phase 2 starts on a LAN host (jessie's minecraft job) to exercise AutoInterface locality, never the fleet-wide VPS paths.

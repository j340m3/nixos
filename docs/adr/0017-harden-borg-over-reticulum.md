# ADR-0017: Harden borg-over-Reticulum after adversarial audit

**Date**: 2026-11-13
**Status**: accepted
**Deciders**: jeromeb + borg-over-RNS security audit grilling session
**Knowledge**: docs/wiki/syntheses/rnsh-retirement-audit.md,
docs/wiki/concepts/rnsh-listener-security.md, docs/wiki/sources/rns-shared-instance-rpc.md

## Context

The borg-over-RNS machinery (commits `4949ab0`..`7d56c94`, built with another
agent) replaced the ssh/nebula backup transport with RNS links: a shell script
shadows `ssh` and dials `rnsh` listeners for hostnames containing `-rns`; woody
runs two such listeners — one bridging to `nix-daemon --stdio` (user
`remotebuild`), one to `borg serve` (user `borg`, own RNS identity). The owner
asked for an adversarial security review of exactly this machinery before
trusting it. Threat-model priorities set in grilling: (b) other participants of
the public RNS testnet and (c) compromised fleet hosts, then (d) local
processes on a host, then (a) internet scanners.

The audit verified the transport-crypto foundations in RNS 1.5.7 source
(fleet pin): `rnsh -l -C ... -- <cmd>` listeners cannot be made to run
anything but the pinned command (any non-empty client cmdline terminates the
session); the `-a` allowlist validates an Ed25519 signature under the link
key, so identity hashes are cryptographic, not loose string matches; links
have per-link ephemeral X25519 forward secrecy; the 2026-07-19 "severe rnsh
flaw" (RNS 1.3.9, details never disclosed) is already patched at 1.5.7. The
archived GitHub `rnsh` repo is irrelevant: rnsh was rewritten and merged into
the RNS package itself (first-party maintained). rsReticulum (Rust port with
`rnsh-rs`) was evaluated and rejected for now: self-declared experimental,
baseline RNS 1.4.2 vs fleet 1.5.7, solo maintainer with closed PRs, not on
upstream's official community-implementation list.

The audit findings (ranked):

- **F1** — the rnsh-borg listener's `--restrict-to-path` covered the whole
  `/var/lib/borgbackup` tree, so any allowlisted RNS client could read/append
  every mesh repo (the ssh accept side enforces per-repo forced commands; the
  RNS side did not).
- **F2** — `rpc_key` was `sha256("reticulum-rpc-<hostname>")`, computable by
  any local process from the hostname alone. The local shared-instance
  control plane (drop paths, blackhole identities, read topology) rides
  abstract AF_UNIX sockets with no filesystem permissions, so that key was
  the *only* gate. The old config also leaked the real key into the store via
  the `restartTriggers` `writeText`.
- **F3** — the `borg` user was in group `reticulum` and could read both
  private RNS identities (fleet/nix-bridge and borg bridge). Possession of a
  private key lets an attacker impersonate that listener on the RNS network.
- **F4** — the rnsh-nix allowlist was all of `constants.reticulum.identities`;
  lenny/rex/slinky/mrpotatohead got a nix-daemon bridge they don't have on
  the ssh accept side (their authorized keys there are commented out).
- **F5/F6** — `rnsd` parsed untrusted wire traffic as root with no
  sandboxing.

Accepted/unchanged by decision: borg repos stay unencrypted for now (owner
not comfortable yet; NAS-first plan, rclone crypt for the later offsite leg);
rsReticulum not adopted; ssh shim shadowing of real ssh accepted (fall-through
verified); shared-instance data plane has no attach auth (local-only, RNS
design); the `BORG_RSH` one-line rollback to the nebula ssh path stays intact.

## Decision

Fix F1–F6 as ordered small commits, each verified by eval before landing:

1. **f8bcfcc (F4)** — rnsh-nix allowlist = `lib.filter (h: h != host)
   (lib.attrNames constants.buildHosts)`, i.e. exactly the hosts that dial
   the nix bridge as remote builders, mirroring the ssh accept side.
2. **42f1e78 (F1)** — woody's rnshBorg gets `repoPath =
   "/var/lib/borgbackup/pricklepants"` (WorkingDirectory + restrict-to-path =
   that one repo); the pricklepants job dials `borg@woody-borg-rns:.`, which
   resolves against the listener's working directory. Per-client repo scoping
   now matches the ssh side.
3. **393341d (F2)** — `/etc/reticulum/config` is a static template holding
   `rpc_key = @rpcKey@` only; `reticulum/rpc_key` becomes a sops secret
   (mode 0400, root) rendered by `reticulum-identity.service` into
   `/run/reticulum/config` (0440 root:reticulum; a borg copy in
   `/run/reticulum-borg/` when rnshBorg is on). All consumers symlink the
   rendered copy; nothing secret-bearing enters the store. Fail-closed: a
   missing sops key leaves the literal placeholder in the rendered config and
   RNS refuses to start. Keys were generated per host via the operator's
   rbw sops-age key (`SOPS_AGE_KEY=$(rbw get age-key-nixos)`) with
   `sops --set '["rpc_key"] "<64-hex>"' secrets/hosts/<host>/reticulum.yaml`
   for the 8 hosts with reticulum enabled (zurg/bully have reticulum
   disabled), and committed in `77fcadd`. Future hosts (or rotation):
   `just rpc-key <host>` creates or rotates the key in one step, encrypted
   per the host's `.sops.yaml` rule (commit `75d95a6`).
4. **530b98b (F3)** — group split: `reticulum` (fleet identity + rendered
   config readers, the rnsh-nix side) vs `rnsh-borg` (borg bridge identity +
   its config copy only). The borg identity secret is 0400 root:root, decoded
   by a root ExecStartPre into `/run/rnsh-borg/`. A compromised remotebuild
   can no longer impersonate the borg bridge and vice versa.
5. **fb33dd5 (F5/F6)** — `rnsd` runs as a dedicated unprivileged system user
   (no capabilities, sandbox: ProtectSystem=strict, ProtectKernel*,
   RestrictAddressFamilies, CapabilityBoundingSet="", …) with ownership
   migration of the legacy root-owned state tree in ExecStartPre. rnsh-borg
   gets the strict variant with ReadWritePaths limited to its repo;
   rnsh-nix deliberately keeps fewer restrictions (the served nix-daemon
   writes /nix, needs build namespaces and host /tmp);
   `reticulum-identity` is a minimal hardened root oneshot.

Mechanism note (asked for explicitly by the owner): `rpc_key` is a stock,
documented Reticulum option — the admin credential of the local shared
instance. Non-root RNS programs attach to the host's shared `rnsd` daemon;
their first `Link` triggers a control-plane check (`is_blackholed`) which
fails with `AuthenticationError` unless the attaching process knows the key
(the default key derives from the root-only `transport_identity` private key
file, which non-root users cannot read — hence the explicit key, now random
and sops-stored instead of hostname-derived). The key never leaves the host
and is not part of the wire protocol.

## Consequences

- The RNS bridge now enforces the same trust boundaries as the ssh side:
  per-repo borg scoping, an nix-bridge allowlist equal to the actual remote
  builders, and identity files readable only by the owning listener.
- Local compromise cost rises on every host: rnsd and the listeners run
  sandboxed and unprivileged; the control-plane credential is unguessable.
- Deployment dependency: every reticulum host needs its `rpc_key` sops entry
  BEFORE `nixos-rebuild`, or the reticulum units fail (intentionally,
  fail-closed). Deploy order: run the key script, commit re-encrypted
  secrets, then rebuild hosts.
- The one-time rollback stays available: switching a client's `borgRsh` back
  to the nebula ssh path is a one-line change per job; disabling
  `services.reticulum.rnshBorg` removes the RNS listener side.
- Revisit triggers for rsReticulum: stable release with RNS ≥ 1.5.7 wire
  parity, inclusion on upstream's official implementation list, and
  restoration of active maintenance.
- Deferred (owner decision): repo-level encryption — to be enabled when the
  offsite (Filen via rclone, likely rclone crypt) leg is designed, since the
  NAS-first copy would otherwise store plaintext in a third-party cloud.

# Yggdrasil as backup overlay for builders and cache

**Date**: 2026-10-17
**Status**: approved design (spec)
**Deciders**: j340m3

## Context

Nebula (ADR-0005) is the backbone overlay, and lighthouse degradation shows quickly. If lighthouse VPSs go
offline (or the internet path degrades), remote builds fall back to local and the
private harmonia cache on woody becomes unreachable. Yggdrasil already exists as a
skeleton in `modules/yggdrasil.nix` (imported only by woody, no peers) and was
previously evaluated for the same-LAN hairpin problem only.

Decisions made with the user:
- **Purpose: both.** Yggdrasil becomes a general second backbone (peered over the
  public internet) with LAN-direct routing as a bonus.
- **Scope: mesh members only** — the 7 hosts that already provide/consume builders
  and cache (lenny, rex, woody, jessie, mrpotatohead, pricklepants, buzz). Wired
  through the nebula module chain so zurg + slinky auto-join when they enter the mesh.
- **Builders: duplicate `buildMachines` entries** — primary dials the nebula path,
  secondary dials ygg, offset `speedFactor` so nebula is preferred. Nix keeps
  building via whichever path works.
- **Cache: one URL** — `https://cache.kauderwels.ch` (AAAA record = woody's ygg
  address) works over every transport and keeps name-based TLS.

## Design

### 1. Constants (single source of truth)

`global/constants.nix` gains, per host in the `host` table:

```nix
host = {
  pricklepants = { ip = "..."; endpoints = [...]; ygg = null; yggPub = null; };
  ...
};
```

`ygg` (address) and `yggPub` (node box pubkey) are `null` until harvested in one
round per host (`yggdrasilctl getSelf` after first boot returns both — same recipe
as the `ip.nebula` enrollment flow documented in the buildHosts comment). All
consumers are `null`-guarded so the flake evals green before addresses are filled.
Ygg addresses and box pubkeys are public facts — they sit in constants unencrypted.

### 2. Overlay module

`modules/yggdrasil.nix` rewritten as a real member module
(args: `{ lib, pkgs, config, constants, ... }`):

- Non-lighthouse peers: `tls://<lighthouse public endpoint>:${yggPort}` for every
  lighthouse except self (endpoints come from `constants.host.<l>.endpoints`,
  the same public IPs as nebula's staticHostMap).
- Lighthouses (`constants.lighthouses`): `"Listen": ["tcp://0.0.0.0:${yggPort}"]`,
  plus WAN firewall allowance on that port (in the module, `mkIf isLighthouse`).
- `IfName = "ygg"` (fixed name for stable firewall rules).
- `persistentKeys = true` as today.
- `AllowedPublicKeys` = the fleet's harvested box pubkeys (`filterMap` of
  `constants.host.*.yggPub`, non-null only). The ygg network is a public overlay —
  this pin is the node-level access control: non-fleet nodes cannot peer to our
  lighthouses or send traffic through our nodes; anything else (scanning, TCP
  flags) stays possible and is handled below.

Membership wiring:
- `modules/nebula.nix` imports `../yggdrasil.nix` (mesh member ⇒ ygg member).
- `hosts/headless/pricklepants/default.nix` and `hosts/headless/buzz/default.nix`
  add the `../../../modules/yggdrasil.nix` import beside their inline nebula blocks
  (they define nebula inline, not via the module).
- zurg/slinky: no action; they get it automatically when imported into nebula.

### 3. Builders (distributed-builds.nix)

Per builder with `ygg != null`, two `nix.buildMachines` entries — both dial by
**alias name** (fixes the identity gap where `hostName = connect-IP` bypassed
the ssh-config block holding `IdentityFile /root/.ssh/remotebuild`):

- `Host <name>` block: `HostName <nebula ip>`, `Port ${sshPort}`, `User remotebuild`,
  `IdentitiesOnly yes`, `IdentityFile /root/.ssh/remotebuild`.
- `Host ${name}-ygg` block: same fields, `HostName <ygg address>`.
- Primary entry: `speedFactor = 10` (preferred); secondary `-ygg`: `speedFactor = 1`
  (overflow/backup only).

`services.openssh.knownHosts` (in `modules/common/ssh-identities.nix`) extends
`hostNames` from `[ name, nebula ip ]` to `[ name, nebula ip, ygg address ]` when
`ygg != null` — same host pubkey covers both paths.

### 4. Cache

- `modules/common/update.nix`: restore the commented substituter
  `https://cache.kauderwels.ch` + its `trusted-public-keys` entry.
- `modules/harmonia.nix`: opens **only 443** on `networking.firewall.interfaces."ygg"`
  (`mkIf` harmonia enabled + ygg member) — no 80, no plaintext 5000 on this interface,
  unlike the nebula block.
- **Outside the repo (user action)**: one registrar-side AAAA record,
  `cache.kauderwels.ch` → woody's ygg address, once harvested.

### 5. Security model

The yggdrasil overlay itself is public and untrusted; access is secured in layers:

1. **Node-level**: `AllowedPublicKeys` pinned to fleet box pubkeys — non-fleet
   ygg nodes can neither peer with us nor send traffic through us.
2. **Service-level**: on the ygg interface only the TLS (443) cache and the
   key-only remotebuild ssh (42069) listen. A node without a fleet key has no
   reachable service; remotebuild accepts key-authed logins only.
3. **Integrity**: the cache is a content-addressed artifact store — any fetch
   surface is read-only; insertion is guarded by harmonia's signature, so cache
   responses to non-fleet ygg nodes could not inject anything even if they could
   reach it. Builds require ssh keys; cache confidentiality is nil because nix
   store objects are public artifacts.
4. **DNS honesty**: the public AAAA is routing, not a trust mechanism — ygg
   addresses are globally routable regardless; hiding them buys only obscurity
   (a scanner would find them via the mesh's world map anyway).

### 6. Error handling

No daemons, no health checks. Nebula down ⇒ ygg path answers; both down ⇒ nix's
existing local fallback; DNS hiccup ⇒ nix skips the unreachable cache and consumes
the next substituter. `persistentKeys` keeps ygg addresses stable across rebuilds.

## Testing

- Eval: all x86 hosts (`config.system.build.toplevel.drvPath`), plus the pointed
  evals — ssh config blocks (`pricklepants` + `pricklepants-ygg` present, correct
  HostName), `buildMachines` 2×5 entries, firewall port sets on the ygg interface
  (443-only on woody), `AllowedPublicKeys` contains each fleet pubkey as harvested,
  substituters list contains the cache URL. `null`-guarded pre-harvest state stays green.
- On-host (user): harvest `yggdrasilctl getSelf` per host and fill constants; publish
  the AAAA record; then prove the backup path with a manual fetch/build over ygg
  (e.g. `nix store ninfo`/`nix store copy` against a `-ygg` alias with nebula down).

## Open items

- ygg private keys are kept `persistentKeys` (auto-generated at first boot). If the
  user later prefers deterministic-before-first-boot addresses, the alternative is
  pre-generating keys offline and pinning them via sops — deliberately not done now.
- The ygg peer port is a constant (`yggPort`) rather than reusing 42069, so the
  overlay's control plane stays distinguishable in firewall logs.

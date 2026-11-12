# ADR-0016: Unify copy-paste host configuration into aspects, collectors, and flavors

**Date**: 2026-11-11
**Status**: accepted
**Deciders**: jeromeb + unify-aspects grilling session
**Knowledge**: docs/wiki/syntheses/unify-aspects.md (commit map, verification recipe, delta ledger)

## Context

ADR-0014 made sharing cheap — every file is an auto-imported module and every
host lists the aspects it uses — but a duplication inventory (sub-agent sweep,
2026-11-04) still found heavy copy-paste above that level:

- `bootstrap-impermanent/configuration.nix` was a ~90% verbatim copy of
  `bootstrap/base.nix` (~250 duplicated lines over the pair).
- Nebula lighthouse config was inline in buzz + pricklepants (~90 lines each)
  and the three `sops.secrets."nebula/*"` blocks existed three times, differing
  only in secret `path` (`/nix/persist/etc/nebula` vs `/etc/nebula`).
- The "open a port on the mesh" triple (`firewall.interfaces."nebula.mesh"` +
  nebula inbound rule + enable gate) was repeated in 7 modules.
- Locale/timezone/zram/xkb blocks were re-set per host although shared aspects
  already define them; the sudo-lecture block ×2; `upgradeHealth.enable` ×5;
  the `modulesPath` profile-footer combos across the 4 VPS hosts; and the 4
  `modulesPath` hosts re-set `boot.tmp.cleanOnBoot`.

Scope was settled by grilling as **option (b)**: low-risk/high-volume clusters
plus profile-level mop-up. Excluded: user/credentials consolidation (hashed
passwords, stale SSH key lists in several host files — option (c) deferred)
and woody's `i18n.defaultLocale = "en_US"` drift.

## Decision

Strict zero-behavior-change refactor, landed as ordered per-cluster commits on
`unify-aspects` (merged into `main` history), each verified by toplevel
derivation-path equality (`nix eval
.#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`) against a
pre-change baseline:

1. **c3aa130 — dead-comment sweep** (template essays, superseded blocks;
   −536 lines).
2. **16647fb — host re-set deletions** where shared aspects already define the
   value (locale/timezone/zram; −69 lines).
3. **9c0b576 — `vps-guest` aspect** for the 4 VPS hosts (sudo-lecture block +
   `upgradeHealth.enable = true` with its comment); woody keeps its own line.
4. **0c378cf — bootstrap split**: `bootstrap-core` (the 90% shared body) plus
   two layout modules (`btrfs-root` vs `tmpfs-root` + btrfs `/nix`);
   `bootstrap-base = core + btrfs-layout` so the `buzz` import is untouched.
5. **0d26b91 — `mesh.openInbound` collector** (carrier option in
   `modules/nix/mesh.nix`, wired into `lib.mkNixos`): feature modules
   (ssh, comin, grafana, harmonia, radicle, loghost, woody) contribute mesh
   ports instead of each writing the firewall + inbound + gate triple; the
   nebula aspect renders the rules.
6. **c612fba — nebula lighthouse flavor**: `flake.modules.nixos.nebula-lighthouse`
   (isRelay, empty lighthouses/relays, v4 listen, capability override) plus a
   `mesh.nebulaSecretDir` option parameterizing the sops secret paths;
   buzz/pricklepants import the flavor and keep only their true deltas
   (punchy drift, DNS serving, lighthouse-specific inbound ports).
7. **c6a22db — fill-ins**: `services.xserver.xkb` (`layout = mkDefault "de"`,
   `variant = mkDefault ""`) into the locale aspect; new `basics` aspect
   (`boot.tmp.cleanOnBoot = mkDefault true`) imported by `system-default`;
   per-host copies deleted. The one intentional behavior change — slinky's
   tmp-clean newly enabled — was explicitly approved in the session.

Design rules:

- **Drift is preserved verbatim, not silently unified.** Where a host disagrees
  with the shared value (buzz/pp `punchy.reload` vs aspect `respond`,
  `listen.host` `"0.0.0.0"` vs `"[::]"`), the host keeps a small explicit
  `mkForce`/override with a comment; unifying it is a separate decision.
- **Flavor modules over option fences.** Roster-derived lighthouses are a
  settled set, so the lighthouse flavor is a second aspect importing the
  member aspect — cheaper and clearer than `mkIf` gates inside the shared body
  (a `mkIf (!isLighthouse)` gate would have broken roster lighthouses jessie
  and mrpotatohead, which import the member aspect).
- **Collectors over per-module wiring.** Cross-cutting per-feature boilerplate
  (mesh ports) collapses into one carrier option consumed by one aspect.
- **Behavior changes need explicit user approval**; the only two approved
  ones (jessie + slinky `cleanOnBoot` via `mkDefault` fill-in) are recorded
  above and in the synthesis.

## Alternatives Considered

### Full consolidation including users/credentials
- **Why not**: hashed-password and authorized-keys duplication may be
  intentional per host; several host files carry stale key lists. Needs its
  own audited pass (deferred, option (c)).

### Fix drift in the same commits
- **Why not**: mixing behavior changes into a refactor makes the drvPath
  equality check meaningless; every drift fix is now a small, reviewable
  follow-up with the checker as safety net.

### lib-function helpers (`flake.lib`: mkProxyVhost, mkRcloneMount, dns01Ionos, borg client jobs)
- **Why not (yet)**: settled as plain `flake.lib` functions, one file each
  under `modules/nix/lib/` (published via an `options.flake.lib =
  attrsOf unspecified` carrier), but lower value-per-risk than the clusters
  above; parked for a follow-up pass.

### Factory/framework (deep-module classes)
- **Why not**: dendritic aspects + collectors already reach the goal; another
  framework layer contradicts ADR-0014's anti-pattern list.

## Consequences

### Positive
- Net −740 lines across the seven commits (−528, −68, +8, −57, +5, −91, −9)
  with zero host behavior changes beyond the two approved `cleanOnBoot`
  fill-ins.
- One place per concern: mesh ports, nebula secrets dir, lighthouse flavor,
  tmp-clean, xkb defaults.
- The drvPath-equality protocol (documented in the synthesis) is now the
  house recipe for refactors of this kind.

### Negative
- Documented semantic-neutral deltas remain (nebula inbound rule order +
  duplicate-rule removal on buzz/pp, `system-path` buildEnv hash from
  systemPackages provenance moves, nebula@mesh restart-trigger hash) — each
  verified as allow-only/provenance-only in the synthesis ledger.
- Roster coupling: `nebula-lighthouse` is derived from
  `constants.lighthouses`; a new lighthouse must join the roster *and* import
  the flavor.

### Risks
- Drift re-introduction: new hosts may copy-paste again — mitigated by the
  conventions section in the synthesis and code review habit.
- bootstrap-layout coupling: `bootstrap-base` pins the btrfs-root layout;
  future layout additions must keep the disko image output names (`image`,
  `image-impermanent`).

## Status update

2026-11-11: all seven commits landed and verified (9 hosts byte-identical
drvPaths per commit; slinky verified by targeted option evals due to the
aarch64 IFD wall). Deferred queue lives in
`docs/wiki/syntheses/unify-aspects.md`.

2026-11-12: deployed to `main` (fleet autoUpgrade source) and merged with
upstream rnsh-bridge work; the deferred queue was then fully executed
(drift fixes, the four `flake.lib` helpers under `modules/nix/lib/`,
fail2ban + postgres skeletons, root-SSH policy + credentials convergence
— details in the synthesis). The ADR was renumbered 0015 → 0016 after the
merge brought upstream's own ADR-0015 (borg-over-reticulum-rnsh-bridge).
Migration closed.

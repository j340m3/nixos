# Unify-aspects dedupe migration — synthesis

Date: 2026-11-04 → 2026-11-12. Decisions: ADR-0016. Trigger: user question
"It feels like there is a lot of copy-paste code in this repo, can we unify
to more aspects?" (settled via two grilling rounds; scope = low-risk/high-volume
clusters + profile mop-up).

## Commit map (branch `unify-aspects`)

| Commit | Cluster | Files | Δ |
|---|---|---|---|
| c3aa130 | dead template comments + superseded blocks | 9 | +8/−536 |
| 16647fb | locale/timezone/zram re-sets covered by shared aspects | 4 | +1/−69 |
| 9c0b576 | `vps-guest` aspect (sudo lecture + upgradeHealth) for buzz/jessie/mrpotatohead/pricklepants | 5 | +30/−22 |
| 0c378cf | bootstrap split: `bootstrap-core` + `btrfs-root` / `tmpfs-root+btrfs-/nix` layouts; `bootstrap-base` = core+btrfs (buzz untouched) | 5 | +407/−464 |
| 0d26b91 | `mesh.openInbound` collector option (modules/nix/mesh.nix) wired via `lib.mkNixos`; ssh/update/grafana/harmonia/radicle/loghost/woody contribute ports; nebula aspect renders rules | 12 | +88/−83 |
| c612fba | `nebula-lighthouse` flavor + `mesh.nebulaSecretDir` option; buzz/pp inline configs collapsed to their deltas | 5 | +82/−173 |
| c6a22db | xkb `mkDefault "de"`/`""` fill-in in locale aspect + new `basics` aspect (`boot.tmp.cleanOnBoot = mkDefault true`, imported by system-default); 5 host copies + 3 xkb blocks deleted | 8 | +14/−23 |

## Verification protocol (now the house recipe)

1. Before touching anything: write per-host toplevel drvPaths to a baseline
   file:
   `nix eval --raw .#nixosConfigurations.<h>.config.system.build.toplevel.drvPath`
   for the 10 x86 hosts. Commit that state first (drvs must be reproducible
   from a fixed rev).
2. After each cluster commit: re-eval and diff. Byte-identical drvPath = the
   exact same build plan; any difference must be explained down to a single
   option change and judged semantic-neutral (or user-approved) *before*
   landing the commit.
3. slinky is IFD-bound (aarch64 kernel): verify by targeted option evals
   (`nix eval --json .#nixosConfigurations.slinky.config.<option>`) old
   (`git+file:.?rev=<FULL-SHA>`) vs new — never a full toplevel.
4. `deadnix` + `statix` pre-commit hooks run automatically; new files must be
   `git add`ed *before* evaluating (dirty-tree eval ignores untracked files).

## Semantic-neutral delta ledger (documented, verified)

- **0d26b91**: jessie + woody toplevel drvPaths differ only in
  `nebula@mesh.service` X-Restart-Triggers hash — the rendered yaml allow-rule
  *order* changed (collector appends after the static rules) and the rendered
  set is unchanged (allow-only rules; duplicate ssh-port rule on buzz/pp
  collapsed later in c612fba).
- **c612fba**: buzz `nna4kd8→a5pb43ji`, pricklepants `78fk934→y0d17j56`:
  inbound rule reorder + duplicate 42069 rule removal (allow-only),
  `environment.systemPackages` same set but `nebula` moved provenance
  (host file → aspect contribution) → `system-path` buildEnv drv hash changes
  with unchanged symlink-farm content. All other hosts byte-identical.
- **c6a22db**: jessie `m2sfhmki→kn0k8sha` = the user-approved fill-in
  (`boot.tmp.cleanOnBoot` false→true; no other boot.tmp change). Headless
  hosts byte-identical prove the xkb `mkDefault` never enters non-X
  toplevels. slinky: `cleanOnBoot` false→true (approved), xkb stays
  `{layout="us", options=eurosign:e,caps:escape, variant=""}`.

## Design patterns that carried the work

- **Flavor module**: `nebula-lighthouse` imports `nebula` and overrides the
  lighthouse deltas (isRelay, empty lighthouses/relays `mkForce []`,
  `listen.host = "0.0.0.0"`, capability mkForce). Chosen over `mkIf` gates in
  the shared body because roster lighthouses jessie/mrpotatohead import the
  member aspect — a negated gate would have zeroed their config. Note:
  `flake.*` definitions must live at file level, not inside a host-level
  NixOS module body ("option flake does not exist").
- **Collector option**: `mesh.openInbound` (list of {port, proto}) defined
  once in `modules/nix/mesh.nix` (top-level in the `mesh-ports` module), fed
  into every host by `lib.mkNixos`; feature modules append their ports; the
  nebula aspect maps them into inbound rules. No enable-gate `mkIf` chains.
- **Parameterized secret dir**: `mesh.nebulaSecretDir` (str, default
  `/etc/nebula`) replaces three hardcoded sops paths; buzz/pp set
  `/nix/persist/etc/nebula`.
- **Upstream knowledge that saved the day** (nixpkgs nebula module,
  rev 55bfb4d): upstream itself opens UDP 4242 for lighthouse/relay networks
  (our redundant aspect line was deleted with zero drift); `listen.host`
  defaults to `"0.0.0.0"`; `lighthouse.dns.*` are typed options always
  rendered, so pp's inline `settings.lighthouse = { serve_dns = false; }`
  matched the typed defaults exactly; rendered yaml key order is sorted, so
  nix definition order is irrelevant.

## Preserved drift (explicit overrides, follow-up candidates)

Resolved 2026-11-12 (commit 13d9318, user-approved): punchy unified to
`{ punch, respond, reload }` fleet-wide, all lighthouses listen dual-stack
`[::]`, woody moved to `de_DE.UTF-8`, and jessie/mrpotatohead import the
`nebula-lighthouse` flavor (relay-consistent). The list below records the
pre-unification state.

- buzz/pp `settings.punchy = mkForce { punch = true; reload = true; }` vs the
  shared aspect's `{ punch = true; respond = true; }` (different nebula
  features, not equivalent).
- buzz `listen.host = "0.0.0.0"` vs aspect `mkDefault "[::]"` (members listen
  dual-stack, buzz v4-only).
- woody `i18n.defaultLocale = "en_US.UTF-8"` with de_DE `LC_*` (excluded from
  scope; decide whether drift or bug).
- jessie/mrpotatohead are roster lighthouses *via the shared aspect* — they
  do NOT import the flavor; if their mesh behavior should match buzz/pp,
  import `nebula-lighthouse` there too (behavior change, needs evaluation).

## Deferred queue (out of ADR-0016 scope) — COMPLETED 2026-11-12

The queue was executed as commits 13d9318 → 63bc2db on `main` (pushed
`f608c93..63bc2db` after the rnsh-bridge rebase):

1. **Drift resolutions** — 13d9318: punchy unify (verified against
   slackhq/nebula: `respond` is connect-back to actively-handshaken peers,
   cert-authenticated, no new inbound surface), dual-stack listen on all
   four roster lighthouses, woody `de_DE`, jessie/mph → `nebula-lighthouse`
   (fixes relay.relays advertising relays that had `am_relay = false`).
2. **`flake.lib` helpers** — acme-dns01 (cf2fd71, ×4 IONOS certs), proxy-vhost
   (295460f, ×6 vhosts), rclone-mount (fbe08d8, ×6 mounts, option SETS
   verified identical; consumers woody/mph/rex), borg-client-job (f32f575,
   ×3 jobs + minecraft-java ride-along untouched; pp gained the upstream
   `borgRsh` pin param during rebase on 0f6ace1).
3. **fail2ban jail+filter** (×2) and **postgres collation fix** (×2) —
   f608c93: `lib.fail2banJail` (jail + filter.d override in one unit;
   name-shadowing invariant in the helper header), `lib.postgresCollation`
   (generalized REINDEX/REFRESH loop on `postgresql.postStart` — mph's
   other postgres DBs gain protection the nextcloud-only special case
   never had).
4. **Credentials/root-SSH** — 63bc2db: root SSH login removed fleet-wide
   (the ssh aspect's `PermitRootLogin no` already made pp/mph key entries
   inert; imp was the one live hole — explicit `PermitRootLogin no`, root
   password kept for console/VNC rescue only). imp adopts the shared
   donquezz aspect (+3 keys it was missing). Host-local jeromeb users stay
   on lenny/woody/zurg: converging would change live uids (chown hazard)
   and drop lenny's password (lockout under mutableUsers false). The
   home-manager wiring moved into the nixos.jeromeb aspect.
   Known pre-existing surface, left unchanged: imp does not set
   `services.openssh.settings.PasswordAuthentication` (defaults true there
   since it lacks the ssh aspect).

# Unify-aspects dedupe migration — synthesis

Date: 2026-11-04 → 2026-11-11. Decisions: ADR-0015. Trigger: user question
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

## Deferred queue (out of ADR-0015 scope)

1. **User/credentials consolidation** (grilling option (c)): hashed-password
   and authorized-keys duplication across lenny/woody/zurg/bootstrap* and
   stale key lists; audited pass with explicit key-list reconciliation.
2. **`flake.lib` helper files** (settled shape: one file per helper under
   `modules/nix/lib/`, each publishing via an `options.flake.lib =
   attrsOf unspecified` carrier): `proxy-vhost.nix` (×6 vhosts, watch woody's
   header subtleties), `rclone-mount.nix` (×6 mounts, ~80% shared keys),
   `acme-dns01.nix` (×4 IONOS DNS-01 certs), `borg-client-job.nix` (×3).
3. **fail2ban jail+filter skeleton** (×2) and **postgres collation fix**
   (×2) — small, optional.
4. Drift resolutions from the list above (each its own approved commit).

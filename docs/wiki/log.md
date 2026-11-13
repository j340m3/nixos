# Log

## 2026-11-12 — unify-aspects deferred queue completed [dendritic]

Continuation of the 2026-11-11 migration: deployed to `main` (merged with
upstream rnsh-bridge work; our ADR-0015 renumbered to
[ADR-0016](../adr/0016-unify-aspects-dedupe.md) after the merge brought
upstream's own 0015), then the whole deferred queue executed as
13d9318 → 63bc2db, every commit verified by per-host drvPath equality or
documented approved deltas:

- 13d9318 drift fixes: nebula punchy unified to `{punch, respond, reload}`
  fleet-wide (security-checked against slackhq/nebula first), dual-stack
  `listen.host` on all four roster lighthouses, woody → `de_DE`, jessie/mph
  → `nebula-lighthouse` flavor (relay-consistent with the member roster).
- cf2fd71/295460f/fbe08d8/f32f575: the four `flake.lib` helpers under
  `modules/nix/lib/` — acmeDns01 (×4), proxyVhost (×6 vhosts), rcloneMount
  (×6 mounts, option sets identical), borgClientJob (×3 jobs, anonymous
  module pattern; pp carries upstream's `borgRsh` pin).
- f608c93: `lib.fail2banJail` (jail + filter.d override, name-shadowing
  invariant centralized) and `lib.postgresCollation` (generalized
  REINDEX/REFRESH loop; mph's non-nextcloud postgres DBs gain coverage).
- 63bc2db credentials/root-SSH: root SSH login off fleet-wide — the ssh
  aspect's `PermitRootLogin no` had already made the pp/mph root key lists
  inert; imp was the one live hole (explicit `PermitRootLogin no`, root
  password kept for console/VNC rescue). imp adopts the shared donquezz
  aspect (+3 keys); host-local jeromeb users stay (live-uid chown hazard);
  HM wiring moved into the nixos.jeromeb aspect.

## 2026-11-11 — unify-aspects dedupe migration landed [dendritic]

Task: settle and execute the copy-paste unification the user asked for ("can
we unify to more aspects?"), scoped by grilling to low-risk/high-volume
clusters under a strict zero-behavior-change rule. Decision: ADR-0015.

Landed on `unify-aspects`, seven ordered commits, each verified by per-host
toplevel drvPath equality (10 x86 hosts; slinky via targeted option evals at
the aarch64 IFD wall):
- c3aa130 dead template/superseded comment sweep (−536 lines, pre-inventory).
- 16647fb locale/timezone/zram host re-sets covered by shared aspects.
- 9c0b576 `vps-guest` aspect (sudo lecture + upgradeHealth).
- 0c378cf bootstrap split into `bootstrap-core` + btrfs-root /
  tmpfs-root layouts (`bootstrap-base` unchanged for buzz).
- 0d26b91 `mesh.openInbound` collector option: 7 modules stop hand-wiring
  firewall + nebula-inbound triples.
- c612fba `nebula-lighthouse` flavor + `mesh.nebulaSecretDir`; buzz and
  pricklepants inline ~90-line configs collapse to their true deltas.
- c6a22db xkb `mkDefault` fill-in in the locale aspect + new `basics` aspect
  (`boot.tmp.cleanOnBoot = mkDefault true`).

Findings:
- Verification bar: drvPath equality makes every deviation a one-line
  explanation. Recorded deltas: collector-driven inbound rule order (allow-
  only), system-path provenance moves, and the two user-approved
  `cleanOnBoot` fill-ins (jessie + slinky).
- The roster already lists jessie/mrpotatohead as lighthouses importing the
  shared aspect, so the lighthouse flavor had to be a separate module, not a
  `mkIf (!isLighthouse)` gate in the shared body.
- Upstream nixpkgs nebula module opens UDP 4242 itself for
  lighthouse/relay networks — the aspect's own allowedUDPPorts line was
  redundant and deleted with zero drift.
- Net −740 lines over the seven commits; deferred queue (user/credentials,
  flake.lib helper files, small skeletons) recorded in the synthesis.

Written: syntheses/unify-aspects.md; index.md (new "Unify-aspects dedupe
migration" thread); ADR docs/adr/0016-unify-aspects-dedupe.md.

## 2026-11-04 — ingest | Coral USB TPU for ML log analysis research

Task: research whether a Google Coral USB Accelerator (Edge TPU) can be the ML accelerator for automatic log analysis: (1) can it be used, (2) performance ceiling, (3) implementation difficulty. Research and writing only — no Nix code touched.

Findings:
- Yes, technically feasible: host-featurized logs → fully INT8-quantized TFLite model → PyCoral + libedgetpu delegate on the USB Accelerator; training off-device only. But a poor fit: Edge TPU op set is CNN-oriented (MobileNet/SSD/EfficientDet class); log analysis is text/tabular/time-series (parse → counts/TF-IDF/embeddings → SVM/LSTM/Transformer) running on host CPU; partial compilation falls back to CPU with potential order-of-magnitude slowdown.
- Ceiling: 4 TOPS INT8 peak, ~2 W; official benchmarks 2.1–7.2 ms/inference for small vision models (MobileNet v2 2.6 ms, MobileNet v2 SSD 7.2 ms); ~4.6–4.9 ms steady-state measured for MobileNet V2 via PyCoral; ~8 MB SRAM parameter cache, batch size 1, thermal throttling possible with max runtime; multiple TPUs pipelinable via --num_segments.
- Difficulty: moderate-to-high, likely poor value. Compiler x86-64 Debian only (no ARM64 since v2.1); quantization needs representative log dataset; NixOS has no libedgetpu/pycoral packaging (nixpkgs#188719, open since 2022-08-28); ecosystem maintenance uncertain (libraries reportedly untouched since 2022). PoC: days to ~2 weeks on Debian; robust NixOS pipeline: weeks to months — host CPU or GPU is the better fit for log analysis.

Written:
- sources/coral-usb-accelerator.md, sources/coral-edge-tpu-compiler.md, sources/coral-performance-limits.md, sources/ml-for-log-analysis.md, sources/coral-on-nixos.md
- concepts/coral-tpu-for-log-analysis.md
- syntheses/coral-tpu-log-analysis.md
- index.md (new "Coral USB TPU for ML log analysis" thread)

## 2026-11-03 — sops-nix key sources: fixed zurg "No key source configured for sops" [sops]

Task: make `nixos-rebuild switch --flake github:j340m3/nixos` for host `zurg`
pass evaluation again.

Root cause: zurg imports the `sops` aspect (`modules/system/sops.nix`) and the
`nebula` aspect, which unconditionally declares `sops.secrets."nebula/*"`.
sops-nix (rev 44931708) then asserts a key source when any secret is declared;
zurg runs no sshd and set none of `sops.age.keyFile` / `sops.gnupg.home`, so
evaluation of `system.build.toplevel` aborted with
"No key source configured for sops."

Fix: `services.openssh.generateHostKeys = true;` in
`modules/hosts/zurg/configuration.nix` — generates the ed25519 host key
without running sshd; `sops.age.sshKeyPaths` defaults to that host key, which
satisfies the assertion. Verified:
`nix eval .#nixosConfigurations.zurg.config.system.build.toplevel` now yields a
valid system derivation instead of the assertion error.

Written: concepts/sops.md; index.md lists it under the Nix/NixOS developments
thread.

## 2026-10-22 — php2shell remediation implemented in-repo [php2shell]

Task: assess php2shell (CVE-2026-109618/109619) exposure across all 12 hosts,
mitigate. Research compiled in this vault (see index "PHP php2shell exposure").

Findings: only two hosts execute vulnerable php — **mrpotatohead** (nextcloud35
→ php-fpm, nginx 443, internet-exposed) and **woody** (zabbix74.web → php-fpm,
nginx 0.0.0.0:80 but nixos firewall only admits it on the nebula mesh
interface). Both ata on php 8.4.26 (root pin nixos-unstable @ 55bfb4d,
2026-10-14). rex's zabbix web/server blocks are `/* */`-commented (agent
binary only, not serving); buzz's nextcloud import commented out (host
offline); lenny/sid/slinky/zurg/jessie/pricklepants/bootstrap* serve no php.

Implemented (repo-side only, NOT deployed to hosts yet):
- `nix flake update nixpkgs-master` → 5943ea99, 2026-10-22 (includes
  nixpkgs#576853, php 8.4.27).
- New temporary aspect `modules/system/php84-patch.nix` (overlay: `php84 =
  inputs.nixpkgs-master.legacyPackages.${prev.system}.php84`) imported by
  `system-default`. Verified: nextcloud + zabbix pools eval to 8.4.27;
  `nixpkgs/nixos-unstable#php84` still 8.4.26 (channel lags; keep the patch
  until it reports 8.4.27+, then `nix flake update nixpkgs` and delete the
  module).

Pending (manual): rebuild mrpotatohead + woody (`just rebuild`); grep nginx
logs back to 2026-10-17 for IoCs (see source page). slinky aarch64 eval error
(`inputs` missing in `_uConsole.nix`) pre-exists unrelated migration WIP;
lenny toplevel eval unaffected by the overlay.

## 2026-10-21 — Dendritic Pattern adoption research (initial pass)

Task: compile knowledge for adopting the Dendritic Pattern with flake-parts
(per Doc-Steve's guide) in this repo. Researchand writing only — no repo code
touched.

Fetched/inspected:
- https://github.com/mightyiam/dendritic (README via repo page; `main/README.md`
  404s — default branch is `master`).
- Doc-Steve wiki: Basics, Dendritic_Aspects, Comprehensive_Example, FAQ,
  Acknowledgement_and_additional_information (raw
  raw.githubusercontent.com/wiki/... markdown).
- flake.parts: `/`, `/getting-started`, `/system`, `/module-arguments`,
  `/options/flake-parts-modules`. Old URLs (`overview_mkFlakeOptions`,
  `distribute-packages`, `module-merge`) 404 — site rebuilt as mdBook; the
  systems/perSystem content now lives at /system and /options/flake-parts.
- import-tree: repo moved vic/import-tree → denful/import-tree (GitHub
  redirect; README + links still say github:vic/import-tree). Verified default
  filter in source `tree/default.nix`: only `*.nix`, excludes `/_` paths;
  non-.nix files and extensionless files in the fixture are NOT imported.
- Reference repos cloned shallow to /tmp: mightyiam/infra (import-tree
  filterNot on `.pkg.nix`, flake-file-generated flake.nix, own deferredModule
  options), drupol/infra (den framework, `den.aspects.apollo.includes` +
  `den.schema.user.classes`), Doc-Steve comprehensive example (verified
  host-definition trio, mkNixos option-block, home-manager tool feature).
- Local repo files read: flake.nix, modules/flake/{lib,home,per-system}.nix,
  modules/common/default.nix, modules/hosts/woody/{default,flake-parts}.nix,
  GLOSSARY.md; host list via glob (12 host dirs).

Written:
- sources/dendritic-pattern.md, sources/doc-steve-guide.md,
  sources/flake-parts.md, sources/import-tree.md
- concepts/aspects.md, concepts/host-definition.md,
  concepts/multi-context-home-manager.md
- syntheses/migration-plan-notes.md
- index.md, log.md

Open questions for a future pass:
- dendrix (https://dendrix.denful.dev/Dendritic.html) deep-dive and the
  `den`/dendritic-unflake alternatives were only skimmed via FAQ mentions.
- ~~vic/flake-file `flakeModule.dendritic` internals not fetched.~~
  **Closed in pass 2 (same day, below).**

## 2026-10-21 — flake-file deep-dive (pass 2)

Task: close the open question from the initial pass — flake-file
(vic/denful) internals — as follow-up to the decision to adopt dendritic +
flake-file. Research+writing only.

Fetched/inspected:
- Dendrix book: landing page, `Dendritic.html` (full property list dumped into
  sources/flake-file.md §g), SUMMARY.md of book repo (chapters: Getting
  Started, Dendritic, Ecosystem, Trees/Layers/Conventions, FAQ — no
  flake-file-specific or "setup" chapter; flake-file appears inside the
  Dendritic page).
- flake-file docs site (flake-file.denful.dev): index, explanation/{what-is-
  flake-file,how-it-works}, tutorials/{quick-start,migrate-flake-parts},
  guides/{flake-modules,templates,auto-follow,lock-flattening},
  reference/{options,bootstrap}; source: modules/${default,write-flake,write-
  lock,flake-parts,import-tree,options/{default,inputs,outputs}}.nix,
  modules/dendritic/{default,dendritic,basic,nixpkgs,systems}.nix,
  dev/modules/_lib/default.nix, templates/dendritic/{flake.nix,modules/dendritic.nix}.
- Ecosystem hub via docs sidebars (import-tree, flake-aspects, with-inputs,
  den, garden, dendrix); import-tree unchanged from pass 1.
- Local Nix 2.34.9 verification: flake-file's typed fields (`shallow`,
  `ref`, …) emitted into flake.nix input attrs → `error: unexpected flake
  input attribute` — CONTRADICTION recorded in the source note (put such
  params in the url string); positive test: `flake=false` + two-level nested
  follows lock cleanly.

Written:
- sources/flake-file.md (main deliverable: a)–g) answers, verbatim snippets
  from dendritic/{dendritic,basic,nixpkgs,systems}.nix, easyOutputs presets,
  write-flake writer logic, option schema, bootstrap reference).
- index.md updated (orientation bullet + source #5).
- log.md: this section; open-question line struck through as resolved.

Key answers (details in source note): `flakeModules.dendritic` = default
options/app/checks + import-tree input declaration + flake-parts
`flakeModules.modules` (`flake.modules` classes) + `outputs =
mkDefault "dendritic"` preset (`mkFlake { inherit inputs; } (import-tree
./modules)`) + `systems = mkDefault lib.systems.flakeExposed`; inputs schema
supports two-level/deep nested follows + `flake=false`; generated flake.nix
keeps `mkFlake { inherit inputs; }` so `inputs` stays a normal module arg
(functionArgs); regen loop `nix run .#write-flake` + `nix flake check`
(diff-check `check-flake-file`); write-flake writes ONLY flake.nix unless
`auto-follow` (rewrites both) or prune-lock/allfollow (rewrites lock only) —
adopt with both OFF to protect our hand-tuned follows; bootstrap via
`nix-shell …-A write-flake` for the chicken-and-egg phase.

Open questions for a future pass:
- `den`/dendritic-unflake alternatives still only skimmed (now up-to-date
  name-wise: Den := flake-aspects/den framework; banner in flake-file README).
- flake-file's `flake-file.outputs` literal-string path for an
  already-modularized repo that keeps its own flake-parts module tree (vs
  dendritic preset): no dedicated doc; validate during actual migration.

## 2026-10-19 — initial research and vault creation [reticulum]

Scope: RNS 1.5.x guidance for a public VPS transport node; host `pricklepants` (Ionos). No Nix files edited.

Activities:

- Read the NixOS module `modules/reticulum.nix` and `modules/hosts/pricklepants/reticulum.conf`:
  - transport disabled, discovery learning on, `required_discovery_value = 1`, `autoconnect_discovered_interfaces = 100`;
  - ~23 enabled outbound BackboneInterface clients, AutoInterface, disabled RNode, commented I2P;
  - module firewalls UDP 29716/42671 and multicast, but no TCP listener port.
- Inspected installed RNS **1.5.5** in the Nix store and downloaded the **1.5.7** sdist from PyPI (SHA-256 recorded).
- Verified behaviour in source: transport gating, discovery parsing, stamp semantics, autoconnect eligibility, interface modes, announce rates, IFAC parsing, transport identity persistence.
- Diffed 1.5.5 vs 1.5.7: Discovery.py autoconnect transport check; Reticulum.py static identity for discoverable non-transport; BackboneInterface egress-control reset; rnodeconf changes.
- Read official manual chapters (`networks`, `gettingstartedfast`, `interfaces`, `using`, `reference`, `Changelog`) and the project bootstrapping page. Found that the markdown conversion omits an RST-only redundancy tip.
- Found and read two rns.recipes forum threads: the heavy-load `listen(1)` report (2026-10-18) and the discoverable-mode workaround (2026-10-02). Read the community wiki transport-node page and the deprecated node list.
- Recorded discrepancies:
  - manual stamp default 14 vs code 16;
  - rendered manual has a mode-forcing note missing from the markdown;
  - 1.5.6/1.5.7 lack mirror changelog entries.

Outputs:

- Created `docs/wiki/{index.md,log.md,sources/,concepts/,syntheses/}`.
- Synthesis recommendation: enable transport; public discoverable Backbone gateway; discovery learning on, autoconnect 0, required value 16; prune peers to 3–5; drop AutoInterface; open TCP listener port.

Open items for a future pass:

- Test `listen_on = ::` dual-stack behaviour on the host.
- Re-check whether upstream raises the Backbone backlog / caches announce validation.
- Validate live peers from `directory.rns.recipes`/`rmap.world` before finalizing the retained peer list.
- Confirm Nixpkgs version bump to 1.5.6/1.5.7 and any package-level patch for `listen(1)`.

## 2026-10-19 — implementation: pricklepants public transport node [reticulum]

Implemented the synthesis in the Nix repo:

- `modules/hosts/pricklepants/reticulum.conf`: rewritten from the copied live config. `enable_transport = yes`, `required_discovery_value = 16`, `autoconnect_discovered_interfaces = 0`, `respond_to_probes = yes`; public `BackboneInterface` gateway on `0.0.0.0:4242` (`mode = gateway`, `discoverable`, `discovery_name = pricklepants`, `reachable_on = 194.164.125.154`, `announce_interval = 720`, stamp 20, announce rate 3600/3600/6); AutoInterface and the RNode block removed; five static peers kept: dismail, Germany 001, R-Net Istanbul, Sydney RNS, Sideband Hub (pinned transport identity).
- `modules/reticulum.nix`: removed the AutoInterface UDP 29716/42671 and multicast firewall rules.
- `modules/hosts/pricklepants/default.nix`: added `networking.firewall.allowedTCPPorts = [ 4242 ]` for the listener.
- Verified: config parses with RNS's vendored configobj; listener options re-checked against 1.5.7 source (`listen_ip`/`port`/`listen_on` alias at `Reticulum.py:1119-1122`, announce-rate options per-interface via `_synthesize_interface`); `nix eval` of the pricklepants toplevel succeeds; `nixfmt --check modules/reticulum.nix` passes (pricklepants default.nix was already unformatted at baseline).
- Vault: `sources/pricklepants-config.md` marked stale; synthesis listener option note corrected (`listen_on` is aliased, `port` overrides `listen_port`).

Remaining (operator): copy `/root/.reticulum/storage` → `/var/lib/reticulum/storage` and `/root/.lxmd` → `/var/lib/lxmd` on pricklepants, deploy pricklepants, rebuild woody; never run both identities at once; verify with `rnstatus -a` and `rnstatus -d` from a discovering node.

## 2026-10-21 — dendritic host conversions resumed (pass 3) [dendritic]

Continued from ADR-0014 + adopted-plan. Repo state at start: skeleton +
zurg tracer converted (commit 33570fa); no dedicated handoff file exists —
inferred plan this way.

- Retrying zurg's `_module.args.{inputs,constants}` shim recipe on buzz
  exposed the recursion hazard: any imported plain module that references
  `inputs` in `imports` (bootstrap/_default.nix is the case) makes module-arg
  resolution depend on `config` during module collection → infinite
  recursion. Corrected the recipe (adopted-plan step 2): `lib.mkNixos`
  aspect-mode branch now passes the same transitional specialArgs
  (inputs/constants) as the legacy branch; per-host heads keep their
  original arg list verbatim, zero shim lines.
- Converted buzz (aspect in modules/hosts/buzz/configuration.nix); body
  verified verbatim against the old _default.nix; `just check` green
  (11 ok + aarch64 slinky skip), formatter/statix clean. One commit each.
- Open: 9 hosts remain (bootstrap(-impermanent) last, per ADR-0014 §8);
  each conversion so far is mechanical, the only host-specific care being
  sopsFile depth (file-location sensitive) and imports-time inputs usage.

## 2026-10-21 — host-conversion phase complete (pass 4) [dendritic]

- Converted the remaining hosts, one scripted commit each (rex pattern:
  sed body extraction `/^  imports = \[/,/^}/p`, drop last line, +4 indent,
  verbatim diff check; heads verbatim, resolved by the factory's transitional
  specialArgs): lenny, mrpotatohead (keeps `@args:` — body uses
  `args.extraPublicKeys or [ ]`), pricklepants (has a top-level
  `let rootPath = ../../../.; in` — moved into the aspect head expression),
  sid, woody, slinky, bootstrap, bootstrap-impermanent.
- Discovery: this nix's `nix-instantiate --parse` performs scope-checking.
  Standalone parse fails on free vars like `modulesPath` even though the
  module system supplies them at eval time — heads must bind everything the
  body uses. Also: `nix-instantiate --parse` on a scratch file is part of
  the scripted assembly, before the file even enters the tree.
- Order trap caught: ran `just check` between `git rm bootstrap/_default.nix`
  and its commit → buzz (which imports it) reported `skip buzz ()` from the
  dirty-tree Path error. Post-commit still failed: buzz's import target had
  to change. Restructured to `modules/hosts/bootstrap/_base.nix` (the old
  `_default.nix` byte-identical, plain module), aspect is now a thin wrapper
  importing it, and buzz imports `../bootstrap/_base.nix` — identical
  module set, both hosts eval.
- slinky: converted (parse + verbatim verified), local eval impossible
  (aarch64 eval drags remote builders with failing ssh connections);
  `just check` keeps the documented skip. Needs hardware eval.
- Verified `.#packages.x86_64-linux.image` and `image-impermanent` still
  eval after the bootstrap aspect split (disko image targets intact).
- Housekeeping: `just fmt` is tree-wide; its churn on parked legacy files
  (`home/accounts.nix`, `modules/_common/*`, zurg siblings) was reverted to
  keep the diff scoped; only the converted aspect heads were formatted in a
  follow-up commit.
- Phase closed: every host now routes through `flake.modules.nixos.*`
  aspects via `lib.mkNixos`. Remaining per adopted plan ("not part of host
  conversion"): HM one-source, collector-style refactors, flake-file,
  dropping the transitional specialArgs once it's no longer needed.

## Pass 7 - 2026-10-22

- `_common` grab-bag -> dendritic base feature: `modules/system-default.nix`
  defines `flake.modules.nixos.system-default` importing the parked
  `modules/_common` dir; 8 hosts (buzz jessie lenny mrpotatohead
  pricklepants rex slinky woody) swapped from the path import to
  `inputs.self.modules.nixos.system-default` (commit 7d6ee1d).
- Gotcha re-felt: dirty-tree eval ignores untracked files - the new wrapper
  only worked after `git add` ("attribute 'system-default' missing" until then).
  Same note as skeleton pass; worth a wiki page of its own later.
- Transitional specialArgs (inputs/constants) stays in `modules/nix/lib.nix`
  until sibling aspects absorb `_common/*` files; `_module.args`-style feeds
  are NOT viable for modules referencing inputs inside `imports` lists
  (_common/update.nix comin) - recorded from rex conversion.

## 2026-10-22 - _common peel sweep (pass 5, continued) [dendritic]

- f5c1b88: `_common/*` now peels as per-feature aspects. Shape chosen after
  three failed verbatim-body variants (python surgery kept mis-assembling
  let-body modules; full git-revert): every
  `modules/system/<aspect>.nix` is a THIN wrapper over the still-parked
  original (`flake.modules.nixos.<aspect> = { imports = [ ../_common/<x>.nix ]; }`,
  reticulum -> `../_reticulum.nix` with depth correction).
- `system-default.nix` moved into `modules/system/` and rewritten as the
  aggregate over `with inputs.self.modules.nixos`; it now owns the former
  `_common/default.nix` settings (reticulum enable + radicle insecure
  allowlist) and imports `../../users/donquezz.nix` by path. The old
  aggregator is unreachable; the four agent-md hosts import the aspect.
- gotcha thirds: (1) dirty-tree eval ignores untracked wrappers until
  `git add` - one-line error was "attribute missing" with no hint why;
  (2) empty `()` skip markers in `just check` = the guarded per-host eval
  failed with stderr suppressed; always re-run one eval unsuppressed;
  (3) nix LSP piles bogus parser errors on committed files during fast
  writes - trust `nix eval`/`just check`, never those diagnostics.
- Follow-up queue: absorb each parked body into its wrapper (sopsFile
  depth rule on the move), then re-evaluate the specialArgs countdown
  (update/ssh/ssh-identities/distributed-builds/peerpatrol/home-manager/
  rate-limiting-avoidance/reticulum still consume inputs/constants).

## [2026-10-22] ingest | Nix/NixOS recent developments

Added sources/nixos-26.05-release-notes.md, sources/nixos-announcements.md, concepts/nixos-recent-developments.md. New thread in index.md.

## 2026-10-22 - absorption batches 1-3 (pass 7 continued) [dendritic]

- 11 of 13 parked `_common` features absorbed: their bodies now live in
  `modules/system/<aspect>.nix` wrappers; parked originals git-rm'd; the
  dead `modules/_common/default.nix` aggregator trimmed each batch.
  mem keeps its `commonMem.enable` gate (pricklepants only consumer);
  update/upgrade-health/sops/rate-limiting-avoidance/home-manager/peerpatrol
  absorbed with their `constants`/`inputs` args unharmed - transitional
  specialArgs still feeds them, retirement still waits for batch 4.
- stable absorb recipe (after b12's three failed python surgeries): read
  the original whole, `write` the wrapper by hand, args col-2 -> col-6,
  body +2, closer `}` vs `};` decided per let-shape; nixfmt canonicalizes.
  strip-mode = body WITHOUT its final brace (wrapper supplies `};`);
  let-mode = body inclusive (wrapper replaces the last `}` with `};`).
- probes of the day: statix takes ONE target (`statix check .`);
  `nix eval .#homeConfigurations.jeromeb.config.home.username` (not
  `.home.`); `git diff --stat home` is ambiguous (rev vs path), use
  `home/`; b3e604e also swept in owed move-halves (home/*.nix deletions
  from the HM commit, `modules/system-default.nix` from the peel).
- batch 4 queue: reticulum, agent-md, postgresBackup decision, donquezz,
  dead-aggregator deletion, then specialArgs retirement + lib.nix cleanup.

## 2026-10-22 - absorption batch 4 + _common dir gone (pass 7 closed) [dendritic]

- 7b73949: reticulum (344-line let-heavy body in-wrapped, secrets depth
  `../../secrets/hosts`), agent-md, and a NEW `postgres-backup` aspect
  (was `_common/postgresBackup.nix`, never in the aggregator) are absorbed;
  `_nextcloud` and woody `_immich` now import the aspect;
  `_immich` needed `inputs` added to its args (path imports never fed it).
  `modules/_reticulum.nix` and the parked `modules/_common/` dir are
  deleted - the migration list now ends at specialArgs retirement.
- assembler lesson (third slip, then stable): python slicing that maps
  `src[1:k]` to args SKIPS the opening `{` line - always include the
  brace line explicitly; `write` the file, run nixfmt immediately, let
  the parser catch slip-ups, read the error line.
- tomorrow-notes for retirement: lift `constants` into a wrapper-level
  `let` so inner lambdas go lexical; prune inner arg lists; hosts get
  their own pass; `lib.nix` legacy branch + specialArgs go once no
  `_default.nix` path import survives; root `users/`/`secrets/` stay
  parked by prior decision, so `donquezz` keeps its by-path import in
  `system-default`.

## 2026-10-22 - specialArgs retirement (pass 8) [dendritic]

- full chain b2b852f -> aa8e73b -> 8c25aaf -> 5450536 -> fe81c0d ->
  734d3e3, closing on the adopted-plan's "Done when". Details are in the
  plan file; the short version: everything inside `modules/` now flows
  by wrapper-closure (aspect file defines its aspect value with a
  wrapper-level `let constants` / `inputs`); hosts list
  `inputs.self.modules.nixos.<aspect>` (system-default, services,
  bootstrap-base); `specialArgs` and the legacy `_default.nix` branch
  are gone from `modules/nix/lib.nix`.
- lenny and zurg retain one `_module.args.inputs` hook each - their
  remaining path-imported siblings (lenny's specialisation files,
  zurg's `_llm`/`_update`) only use inputs in option values, the
  hook-safe class; not the comin-in-imports class.
- lessons added: nested /* */ comments swallowed the lenny hook insert
  (debug nix trace pinpointed `attribute inputs missing` from the leaf
  file); `...` never takes a colon before a `}`; when leans at 'skip
  ()' markers in `just check` the guarded eval failed silently - probe
  one eval unsuppressed.
- _common: deleted (dir gone); root users/, secrets/,
  desktop-environments/ still referenced by path from inside features,
  parked by prior decision.

## 2026-10-22 - wave 2: root _-files become services aspects (pass 9) [dendritic]

- c0459d3: the last 12 root feature files (_acme _borg-server
  _fritz-exporter _hardening _nfs-fee _pihole _prometheus
  _remote-builder _vaultwarden _vscodium _wifi _wireguard) moved into
  absorbed-body modules/services/<name>.nix aspects; host configuration
  files + harmonia/nebula swap `../../../modules/_x.nix` for
  `inputs.self.modules.nixos.x`; originals deleted. sed pattern
  `s#^(\s*)../../../modules/_([a-z-]*)\.nix#\1inputs.self.modules.nixos.\2#`
  only matched non-comment lines, so the stale commented imports stayed.
- LESSON: nix eval on a dirty git tree omits UNTRACKED files - new
  aspect files must be `git add`ed BEFORE eval, else
  `attribute 'X' missing` points at the consumer, not the cause.
- LESSON: `just fmt` canonicalizes ALL tracked nix files; pre-existing
  non-canonical parked zurg siblings got swept into the diff -
  `git checkout -- modules/hosts/zurg/` to keep the commit scoped
  (fmt-check still flags those four as pre-session state).
- just check: 11/11 ok, slinky skipped (aarch64, hardware verify).
- Remaining parks: host-local glue siblings + root users/, secrets/,
  desktop-environments/ + lenny/zurg _module.args.inputs hooks.

## 2026-10-22 - host-local service glue absorbed (pass 10) [dendritic]

- bca2e82: woody (nas/xrdp/nofile/firefox/power/zabbix/home-assistant),
  zurg (de/fingerprint/fonts/gaming/llm/update), sid (editor/nvidia)
  inlined into their configuration.nix per the fe81c0d idiom; sibling
  files deleted. Colliding lists folded: firewall allowedTCPPorts +
  nebula mesh ports (woody), systemPackages 4-way fold (zurg incl. the
  inputs.opencode-dev entry). zurg lambda head gained config/lib; the
  `_module.args.inputs` hook is GONE - absorbed bodies see inputs
  lexically from the file head.
- Absorb-pattern lessons: `environment.systemPackages = hostList ++ [x]`
  self-references inside one attrset - put ONE list with entries inline;
  sibling `let` vars move to a wrapper let above the host body (woody
  firefox lock-policies); statix rejects `(...)` around the opencode-dev
  package term in a with-scoped list.
- just check 11/11 (slinky aarch64 skip). Still parked: slinky
  _local/_uConsole (IFD-bound), mrpotatohead _disk-config + 7x
  _hardware-configuration.nix (permanent), lenny specialisation _defs,
  root users/ secrets/ desktop-environments/ (by decision).

## 2026-10-22 - php2shell research + repo exposure check [php2shell]

Task: ingest the 2026-10-21 PHP security release ("php2shell", CVE-2026-109618
OOM-corruption RCE + CVE-2026-109619 stale-global-state RCE, both 9.2),
resolve the upstream fix status, and check this repo's exposure. Research +
writing only; no Nix code touched.

Fetched/inspected: php.net release notes; both php/php-src GHSAs (GHSA-w8hw-
w9fx-j79w, GHSA-6wmf-4rv5-p3rp); ELLIO fields/IoC telemetry; AWS MadPot
timeline; Cloudflare WAF-post; watchTowr + NetSPI/Huntress/Check Point/
Calif.io/Wiz/Datadog/JFrog roundups; nixpkgs PR #576853 and siblings
(#576680/#576852/#576854 closed, #577351 frankenphp open); local flake.lock
and nix evals of the pinned nixpkgs; nixpkgs nextcloud/php-fpm/zabbix module
sources at the pinned rev.

Written:
- sources/php2shell-advisory.md - the fact page: CVE mechanics, version
  ranges (5.4.0-8.5.11 vs fixed 8.2.35/8.3.36/8.4.27/8.5.12), serving-mode
  table, exploitation timeline + IoCs, mitigation levers, nixpkgs status,
  KEV absent, contradictions (watchTowr 5/7 "no patches" vs php.net
  source backports; Red Hat 8.1 vs 9.2/9.8 scoring).
- concepts/php-serving-modes-risk.md - serving mode to exploitability
  matrix, attack-path to config-lever mapping, and the repo's concrete
  exposure (next section).
- index.md - new section "PHP php2shell exposure"; thread-count intro
  refreshed. log.md - this entry.

Repo findings (two corrections over what the passing handoff claimed):
- flake.lock: root `nixpkgs` input follows lock node **`nixpkgs_8`** =
  nixos-unstable @ 55bfb4d7437bd4e09ab7cba58a43bd68eb310044, locked
  2026-10-14 05:35 UTC - NOT the inner node named `nixpkgs` (nixpkgs-
  unstable @ ac6b2166, 2026-08-25), which is only a child input of other
  flakes. LESSON: in this lock the "read the rev off node `nixpkgs`" rule is
  wrong; follow `.nodes[.nodes.root.inputs.nixpkgs]`.
- php at 55bfb4d: 8.3.35 / 8.4.26 / 8.5.11 = the last vulnerable point
  releases (verified by evaluating the pinned rev).
- Which hosts: nextcloud runs on **mrpotatohead** (buzz's config comments
  state the move), woody runs zabbix74.web. Both interpreters resolve to
  **8.4.26**: nextcloud via the module's phpPackage default (php84), zabbix
  via the generic services.phpfpm default (pkgs.php = 8.4.26). nixpkgs-
  master @ 9e917916 (2026-10-17, pre-fix) feeds pkgsUnstable on lenny only.
- verify-at-update recipe is in the concept page: `nix flake update nixpkgs
  nixpkgs-master` once tips include c53532a, eval php84.version >= 8.4.27 on
  the *root-followed* node, rebuild mrpotatohead + woody (switch restarts
  phpfpm-nextcloud/phpfpm-zabbix), hunt logs back to 2026-10-17.

Open for a later pass:
- php82 8.2.35 backport status on nixos-26.05 (no PR visible in search).
- roll the actual update + rebuilds for mrpotatohead/woody when the channel
  carries the fix (operator action, not research).
- optional hardening: nextcloud phpOptions session.upload_progress.enabled=0;
  zabbix pool string-append equivalent; decide same time as the update.

## 2026-10-24 - adoption complete: zero host-local glue (pass 11) [dendritic]

- The dendritic migration is structurally done; grilling + execution
  in this session closed out waves 3-5 on top of pass 10:
  - wave 3 (dbd348c): root `users/` + `desktop-environments/` became
    aspects under `modules/users/` + `modules/desktop/`; system-default
    + 8 hosts rewired to aspect refs (`git add`-before-eval lesson
    reaffirmed; specialisation-loop import of self-referencing aspect
    files = infinite recursion - consumers reference
    `inputs.self.modules.nixos.<id>`, never path-import aspect files).
  - wave 4 (12f1bc2): all 12 hosts are two-file features
    (`configuration.nix` + `flake-parts.nix`) with the 12 underscore
    glue siblings absorbed inline (hardware scans, mrpotatohead disko,
    slinky `/_local` + `/_uConsole` incl. the formerly
    unbound-`inputs` bug - closure via the host head fixes it);
    absorption doctrine: absorbed key may not duplicate a key the host
    attrset already defines (mkForce wins, same-value merges collapse).
  - wave 4b (b05aa69): `global/` moved to `modules/global/`
    (`_constants.nix` - the import-tree `/_`-exclusion became
    load-bearing so the data file is not auto-imported as a module).
  - wave 5 (977184b): `modules/home/xfce/` dir flattened to a flat
    aspect file; 243 lines of dead commented blocks raked.
- Race note: a concurrent wireguard session committed b05aa69 which
  subsumed the wave-4b rename; my duplicate commit was reset before
  push (unpushed-only surgery) - do not `git add -A` shared dirs while
  another session holds the same files; stage explicit paths.
- slinky: eval-green through to the aarch64 IFD wall, but hardware
  verification on the real uConsole is still PENDING (operator task);
  `just check` keeps skipping it until then.
- Bar between every wave: full `just check` green (10 ok + slinky
  skip) before commit; see ADR-0014 status update for the end state.
- Pass 5 [loghost]: after the dendritic push, swept fleet logs. Found and
  fixed: woody's `mnt-filen-services-postgres` never mounted (rclone aborts
  when it cannot open its own log file; `/var/log/rclone/filen/` subdirectory
  did not exist -> tmpfiles rule) and pricklepants' minetest-server had been
  restart-looping since the 2026-10-19 rebuild (luanti 5.17 + June-2024
  VoxeLibre 0.87.2: `mcl_void_damage`/`mcl_grindstone` index nil
  `mcl_spawn`/`mcl_formspec` before their providers load; per-pair mod.conf
  seds were whack-a-mole). Final fix: pin VoxeLibre 0.92.3 from the nix
  store via `LUANTI_GAME_PATH` (gameid comes from the game folder name),
  preStart parks the stale data-dir copy one level deep so the engine stops
  discovering it. Learned: a world.mt `load_mod_... = false` does not
  disable game-shipped mods on 5.16+; remotebuild SSH (port 42069) is
  builder-only, no journal/sudo on peers; fleet logs arrive at woody
  rsyslog `/persist/rsyslog/<host>/`.

## 2026-11-03 - fleet log sweep round 2 [loghost]

Second pass over the centralised rsyslog volume on woody. Ten findings,
five fixed on main the same day; full ledger + user actions in
`syntheses/log-remediation.md`.

- Pass-5 minetest fix (1baad0d) VERIFIED live on pricklepants: current
  generation sets `LUANTI_GAME_PATH=...voxelibre-game-0.92.3`; 0
  `ModError` lines and 0 minetest-server restarts since the switch; the
  residual noise is benign server-lag warnings.
- Root-caused the starved backups: endlessh owns woody :22 since
  2026-10-27 (ssh hardening), real sshd answers on 42069, and all three
  borg clients dialed the tarpit - minecraft-bedrock's repo empty since
  2025-07-08, minetest/pricklepants repos stale. Fix 23475e8 adds
  `-p ${constants.sshPort}` to every `BORG_RSH`. Companion findings:
  `/run/lock/netavark.lock` EROFS under the borgbackup unit's
  `ProtectSystem=strict` (e60f0bf adds `/run/lock` to ReadWritePaths)
  and nightly non-interactive "unknown unencrypted repository" aborts
  (e60f0bf sets `BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK` +
  `BORG_RELOCATED_REPO_ACCESS_IS_OK`; these repos are mesh-local family
  backups, so auto-accept is the right trade).
- Woody host wave 454c3ff: `nm-wifi-env` dotenv service feeds the NM
  wifi profile via environmentFiles; immich-ml gets
  `HOME=/var/lib/immich-ml` (StateDirectory) - both verified live in
  woody's current-generation units. Plus the new
  `modules/services/log-watchdog.nix` staleness aspect (daily, 48h,
  telegram; woody/jessie/mrpotatohead/pricklepants monitored,
  lenny/rex/slinky/buzz `expectedOff`; sid/zurg coverage parked as a
  TODO in `modules/services/logging.nix`).
- mrpotatohead audit narrowing (c4ed4ac) reached the host through its
  hourly nixos-upgrade: `uid=996/989` lines vanished from today's
  audit.log (flood era: 54k). Generic `auid=4294967295` service
  start/stop noise (~10k/day) remains; narrowing further is optional.
- Vaultwarden "Token has expired" spam (109 `GET /api/sync` lines) is
  NOT a server bug: an hourly refresh poller from roaming Telekom IPs
  (80.187.x LTE ↔ 92.209.155.230 DSL) holds a stale refresh token;
  woody's own rbw syncs 200 OK. Action: re-login that device.
- mrpotatohead mesh degradation is chronic, not new: 20339 `Handshake
  timed out vpnAddrs=[10.0.0.6] udpAddrs=[]` in the current log (since
  2026-11-01 00:04), identical timeouts in rotated logs back to
  ≥2025-07. Its lighthouse endpoints (`85.214.10.114` /
  `[2a01:239:4ac:7300::1]`):4242 answer nothing from woody+jessie while
  ping to 10.0.0.7 RTTs 22 ms. Recorded paradox for on-host follow-up:
  potato's logs keep streaming into woody's rsyslog (fresh lines
  throughout the sweep) although `ss` shows no established TCP 514
  session from potato and woody's nebula holds no tunnel to it - the
  carrying transport is unidentified. Needs `ip -brief addr show` /
  `ss` / `journalctl -u nebula@mesh` on the host; then refresh
  `host.mrpotatohead.endpoints` in `_constants.nix` (potato is a
  lighthouse, so every peer's staticHostMap carries the stale pair).
- Coverage matrix from this sweep: active = woody/jessie/mrpotatohead/
  pricklepants; silent = lenny (since 2025-08-26), rex (2025-09-05),
  slinky (2025-09-04), buzz (60/60 empty files yet holding live TCP
  514+42069 sessions into woody during the sweep - it connects but
  sends nothing; watch item). Legacy `/persist/rsyslog/{10.0.0.1,
  127.0.0.1}` dirs and the off-hosts' empty stubs need sudo cleanup
  (commands in the synthesis doc).
- Learned: rsyslog dynafile templates materialise an empty stub per
  (host, program) pair on first touch, so dead hosts amass hollowed
  logs; `/run` is a second read-only frontier under
  `ProtectSystem=strict`, not just the podman store; borg's
  repo-stamp prompt must be preempted via env because hooks run too
  late; `Handshake timed out udpAddrs=[]` means the initiator has no
  address to try, i.e. the peer never registered at any lighthouse.

## 2026-11-04 - fleet log sweep round 3: watchdog timer fix, nebula re-key aftermath [loghost]
Night-2 verification round. mrpotatohead is back (root-CA rotation +
re-key from the parallel live-rebuilds session resolved the
handshake-dead mesh: ping 10.0.0.6 OK, 0 potato timeouts on woody).
The log-watchdog timer never actually ran: requiring the nonexistent
sops-nix.service failed every queue attempt — the fleet renders sops
secrets at activation time (sops-install-secrets inside
switch-to-configuration / nixos-upgrade-start), so no boot service
exists; fixed with ConditionPathExists (da64655). jessie's
minecraft-bedrock borg reached the loghost on 42069, initialized its
empty repo, streamed 774MB over 20min, exited 0 — with data/ still
empty (10 rolled-back transactions): payload watch item for tonight.
Push saga over: rbw unlocked, everything on origin.

## 2026-11-04 — log analyzer stack research [loghost]
Compiled the stack-choice vault for woody's log reporting: Loki 3.7.8 +
Alloy 1.17.1 + Grafana, Graylog 6.1.8 + OpenSearch 3.5, OpenObserve 1.0.4,
Elastic/OpenSearch + Dashboards, Vector + ClickHouse + Grafana, and a minimal
custom analyzer over the rsyslog archive. Checked versions against upstream
(Loki 3.7.9, Alloy 1.21.3, OpenObserve 1.1.2, OpenSearch 3.9 current) and
verified every NixOS module at the pinned nixpkgs rev.

Hard findings: Graylog 6.1.x supports OpenSearch ≤2.15 only (3.x starts at
Graylog 7.2, and the docs warn 3.0+ breaks 6.1 instances), so the candidate
pairing is unsupported. Loki retention is off by default and deletes lag ~2h;
OpenObserve's global default retention is 3650 days; ClickHouse TTL only runs
during merges (~4h default); Alloy's `loki.write` WAL is experimental and
off, so its default delivery is in-memory.

Recommendation: keep rsyslog as the system of record, make sender queues
crash-durable (pure disk, bounded, TCP/RELP), and add a small analyzer over
`/persist/rsyslog` with SQLite state + Telegram digest; Alertmanager optional
for grouping/inhibition; Loki/Grafana as a later search pilot. Strongest
counter-argument recorded in the synthesis: bespoke code rots and Loki is
already one module away. Phase 0 remains disk cleanup on woody (~11 GiB free).

Pages: 12 sources, 2 concepts, 1 synthesis (see index section "Log analysis /
reporting stack choice").

## 2026-11-05 — captive portal circumvention research [captive-portal]

Researched client-side circumvention on Linux/NixOS: iodine DNS tunneling,
dnsmasq/hosts tricks, VPNs/proxies, and NixOS module patterns. Compiled
sources, concepts, and synthesis in docs/wiki/ (see index section "Captive
portal circumvention").

Added sources: iodine-dns-tunnel.md, dnsmasq.md, hosts-file-tricks.md,
vpn-proxy-captive-portal.md, nixos-module-patterns-networking.md.
Added concepts: captive-portal-circumvention.md, dns-tunneling-iodine.md,
hosts-dns-tricks.md, vpn-proxy-patterns.md, nixos-captive-portal-modules.md.
Added synthesis: captive-portal-bypass-comparison.md. Updated index.md and
log.md. No project code modified.

## 2026-11-06 - fleet log sweep round 4: backup verdicts + woody<->pricklepants mesh edge deadlock [loghost]

Backup check requested; findings from the Nov 4-6 runs:

- **minecraft-bedrock (jessie->woody): transport healthy, payload
  unverified.** Repo was re-initialized Nov 4 02:31 (module's
  list->init->create flow auto-healed the empty dir); first full run
  streamed ~774MB/20min, exit 0; Nov 5/6 incrementals exit 0 in ~35s
  (127KB outgoing = dedup against client cache). Server-side `data/` is
  0700 borg so a non-root session cannot count segments — earlier "0
  data segments" readings measured nothing. Suspicion of nightly
  rollback remains: repo `hints.26` is 349 bytes vs minetest's real
  13.5KB hints. Needs one root command to settle:
  `sudo -u borg borg list /var/lib/borgbackup/minecraft-bedrock`.
- **minetest (pricklepants->woody): last successful backup 2025-10-21.**
  Client config is now correct (borg 1.4.5, `-p 42069`, both
  `*_REPO_ACCESS_IS_OK` vars live in its generation) but nightly runs
  die mid-SSH: "Connection closed by remote host", status 2, twice per
  run (list + init attempts) — the mesh edge, not borg.
- **pricklepants (/etc + vaultwarden): repo dir on woody has NEVER been
  initialized** — bare empty directory since 2026-10-16 (module-created
  dir, no config/data). Client job fails nightly -> telegram. Will
  self-heal (module auto-init works on empty dirs, proven locally with
  borg 1.4.5 and by jessie's Nov 4 init) once its ssh sessions survive.
- **matrix (external mtrx client): last write 2025-10-21** — external
  device, not config-managed; user decision.
- **Root cause of 2+3: woody<->pricklepants nebula edge dead since the
  2026-11-03 restart storm** (woody nebula 13:39:02, pricklepants
  14:01:31 — re-key/live-rebuild wave). woody: 24k handshakes sent to
  pricklepants' static endpoints / 24k timeouts / 1 received (Nov 3
  10:24). pricklepants receives woody's packets fine and replies — the
  replies never reach woody; its tunnels to jessie work. Both sides in
  a ~1/s handshake storm for 3 days. pricklepants itself is UP (public
  :42069/:443 open, vaultwarden answering 200) — only the mesh edge is
  dead, which is also why its log shipping stopped Nov 3 13:38 (watchdog
  caught it at 48h, first real catch!).
- **Hardening pushed:** `modules/services/nebula.nix` now opens UDP 4242
  on ALL module-managed hosts (was `mkIf isLighthouse`), so peers can
  always initiate handshakes directly regardless of NAT state.
  Manual fix still needed: `sudo systemctl restart nebula@mesh` on woody
  AND pricklepants to clear the punchy/learned-address cache deadlock.
- **Watchdog works end-to-end:** timer fired Nov 5 + Nov 6 00:0x,
  telegram delivered ("pricklepants: newest log 58h old"), exit 0.
- **rex came back:** k3s desktop shipped logs again Nov 5 (messages/
  k3s.log, ~14:02, then quiet); `virtualboxClientDragAndDrop` restart
  counter at 2717. Roster still treats it as expectedOff — revisit.

## 2026-11-06 - round 5: mesh recovered, rex D&D restart loop fixed [loghost]

- User restarted nebula on woody + pricklepants: ping 10.0.0.1 0% loss
  (32-44ms), received-handshake counter moving again, pricklepants logs
  flowing (messages.log 134MB touched 08:36). Tonight 00:00 the minetest
  job should finally list->init->create and the never-initialized
  pricklepants repo should self-heal. minecraft-bedrock payload check:
  `borg list` as the borg user needs HOME=/tmp (/var/empty is unwritable):
  `sudo -u borg env HOME=/tmp BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes
  borg list /var/lib/borgbackup/minecraft-bedrock`.
- rex restart loop root-caused: `virtualboxClientDragAndDrop` is a
  systemd USER unit from nixos virtualbox-guest.nix (mkIf
  cfg.dragAndDrop, default true); it dies with VERR_HGCM_SERVICE_NOT_FOUND
  because the VM host never exposes the HGCM D&D service, and the old
  in-repo "fix" (systemd.services wantedBy mkForce []) only created a
  bogus SYSTEM unit while the user unit kept looping (2717 restarts by
  Nov 5). Real fix: `virtualisation.virtualbox.guest.dragAndDrop = false`.
- rex is intentionally back (user powered it on Nov 5); roster marks it
  monitor=false — revisit if it ships logs steadily.

## 2026-11-06 - round 6: borg verified, reticulum-logging declined

User closed B1 (`borg list` as borg user: three archives Nov 4-6 — the
"empty data/" scare was a 0700-permission artifact, dedup healthy) and
ran the sudo cleanup (legacy IP-named rsyslog dirs + empty stubs gone).
No borg job prunes; archives accumulate to the 50G server quota by
design (loud failure), years of headroom at current rates.

Decision recorded in [log-remediation](syntheses/log-remediation.md#round-6--2026-11-06-verdicts--reticulum-question):
logging stays on nebula/rsyslog. RNS adds no security over cert-bound
mesh IPs, has no syslog shipper (bespoke Python = new trusted code), and
is the wrong throughput class for ~130MB/day. Right RNS role:
out-of-band LXMF alert path for the watchdog (mesh-blind-spot coverage),
parked as a candidate.

- 2026-10-30: Created wiki structure, researched recent MPTCP CVEs (CVE-2025-71144, CVE-2025-68221, CVE-2025-71126, CVE-2025-40133), documented defaults/check/disable for MPTCP, assessed repo (no mptcp references, defaults likely off) and recommended checking kernel versions/patch levels.

## 2026-11-13 — rnsh security audit for borg-over-RNS [reticulum]

Task: audit groundwork for "borg backup over Reticulum via rnsh" and decide
whether the fleet should move away from the archived rnsh repos. Research and
writing only — no Nix code touched.

Findings:
- The "archived rnsh" premise is misleading: markqvist/rnsh (acehoss fork,
  last push 2026-04-26) is archived, but rnsh was rewritten by Mark Qvist,
  merged into RNS ~2026-04-28, and ships inside the rns PyPI package
  (RNS/Utilities/rnsh, console script rnsh, Reticulum License) — actively
  developed (1.5.7→1.6.0 delta is one line). The deployed rnshPatched tracks
  this maintained copy; no switch needed.
- Listener semantics verified in code: with -C any client cmdline terminates
  the session (session.py:314-318); -a authenticates via LINKIDENTIFY Ed25519
  signature + truncated-hash key pinning (Link.py:969-980, Identity.py:787);
  server authenticated to client by link proof (Link.py:~410-446).
- rpc_key protects only the shared instance's local control-plane RPC
  (attach/detach interfaces, drop paths, blackhole, topology reads), HMAC via
  multiprocessing.connection. On Linux the channels are abstract AF_UNIX
  sockets @rns/default(+/rpc) by default — the configured 37428/37429 ports are
  inert unless shared_instance_type = tcp. Data plane has no auth. Without a
  matching rpc_key an attaching process dies at the first LINKIDENTIFY
  (Link.py:981 → is_blackholed → AuthenticationError) — matches the woody
  module's rpcKey rationale.
- "rsReticulum" is ratspeak/rsReticulum (mmahdavi does not exist): Rust,
  experimental, baseline RNS 1.4.2, ships rnsh-rs but PRs closed and not on the
  official community-impl list (only microReticulum, Reticulum-Go). Beechat
  Reticulum-rs is a library/daemon without shell tooling. rnx is
  client-driven arbitrary exec — unsuitable for the borg contract.
- Zero CVEs/GHSAs for RNS/rnsh (NVD's only "Reticulum" CVE is Mozilla Hubs,
  unrelated). Links: ephemeral X25519 per link → forward secrecy; initiator
  anonymity; destination hash pins the server key.

Action items recorded (no code changes): verify/decide AF_UNIX vs tcp shared
instance binding on woody; keep rpc_key readers group narrow; do not widen the
identity-readers group.

Written:
- sources/rnsh-bundled-rnsh.md, sources/rns-shared-instance-rpc.md,
  sources/rust-reticulum-implementations.md,
  sources/rns-advisories-and-threat-model.md
- concepts/rnsh-listener-security.md
- syntheses/rnsh-retirement-audit.md
- index.md (new "rnsh security audit" thread); version note added to
  sources/rns-1.5.7-source.md (PyPI latest now 1.6.0, flake-pinned nixpkgs
  rns 1.5.7).

## 2026-11-13 — borg-over-RNS audit fixes (ADR-0017)

Following the rnsh security-audit groundwork earlier this day, the audit of
the actual machinery (woody rnsh-nix/rnsh-borg listeners, ssh shim,
rpc_key) produced findings F1–F6; all fixed in commits f8bcfcc (F4
allowlist), 42f1e78 (F1 repo scoping), 393341d (F2 rpc_key via sops,
template + rendered /run/reticulum/config), 530b98b (F3 group/identity
isolation), fb33dd5 (F5/F6 unprivileged sandboxed rnsd + listeners).
Eval-verified on woody/pricklepants/buzz (toplevel drv paths).
Decision: stay on bundled rnsh 1.5.7, no rsReticulum migration; repos stay
unencrypted until the offsite leg; BORG_RSH rollback intact.
Deploy gate: add `["rpc_key"]` to each reticulum host's reticulum.yaml
(8 hosts) before rebuild. See ADR-0017 and the rnsh audit thread above.

Follow-up (same day): per-host rpc_keys generated via the operator's rbw
sops-age key and committed (77fcadd, 8 hosts, verified 64-hex each);
toplevel evals green on all reticulum hosts (slinky via targeted option
evals per IFD convention). Repo is ready to deploy.

## 2026-11-13 — artifact-first updates for memory-starved hosts (ADR-0018) [update]

Grilling session on pricklepants' rebuild memory pressure produced an
artifact-first split: woody's new artifact-publisher aspect (hourly :25)
builds pricklepants/jessie/slinky toplevels from github:j340m3/nixos,
roots the latest closure per host under /var/lib/artifact-publisher/roots/
(GC roots), regenerates manifest.json from surviving links and serves it
over nginx on woody's nebula IP :5001 (mesh-only, both firewall layers,
6G min-free space guard). New artifact-update client aspect (hourly :05)
substitutes the prebuilt closure (harmonia-signature-checked) and
switches; at-most-once per distinct path (state file, manual rebuilds
win), OnFailure starts the untouched nixos-upgrade unit (local eval
fallback, ADR-0000 bar), onSuccess arms the health schedule. Bundled:
pricklepants max-jobs mkForce 1 + idle daemon + swap encryption dropped;
jessie zram 50% re-enabled; fleet builders advertise big-parallel +
aarch64 (buzz/mrpotatohead/woody only); slinky's dead builder-local
entry deleted (ssh alias lost in 425c717). slinky's kernel now reaches
harmonia via woody's store — the four root causes of "kernel caching
never worked" are all addressed. Known limitations: no auto-reboot in
the artifact path; slinky toplevel eval still IFD-bound on x86_64
(publisher *builds* it). Verified: just check ok on all x86_64 hosts;
slinky per targeted option evals. See ADR-0018 and
syntheses/artifact-first-updates.md.

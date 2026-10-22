# Research log

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

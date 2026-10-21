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

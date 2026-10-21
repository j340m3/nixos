# Wiki index — knowledge vault for adopting the Dendritic Pattern (flake-parts)

Purpose: gathered knowledge for migrating the NixOS flake at the repo root to
the [Dendritic Pattern](https://github.com/mightyiam/dendritic) with
[flake-parts](https://flake.parts), per Doc-Steve's guide.

## Orientation

- The pattern in one line: *every Nix file (except `flake.nix`/entry points)
  is a top-level (flake-parts) module that implements one feature across all
  contexts; hosts/users/tools are features too; lower-level modules
  (NixOS/HM/darwin) are option values in the top-level config.* Sources:
  [dendritic-pattern](sources/dendritic-pattern.md) (canonical), FAQ in
  [doc-steve-guide](sources/doc-steve-guide.md).
- Framework: flake-parts provides `mkFlake`, `perSystem`/`systems`,
  `withSystem`, and the class-typed `flake.modules` option
  ([flake-parts](sources/flake-parts.md)).
- Auto-import: `import-tree` imports `.nix` files recursively and skips
  `/_`-prefixed paths ([import-tree](sources/import-tree.md)); optional
  `flake-file` regenerates flake.nix from per-feature input declarations —
  deep-dive in [flake-file](sources/flake-file.md)
  (`flakeModules.dendritic` internals, input syntax, regen loop, lockfile
  safety).

## Notes by task

- Writing features → [aspects](concepts/aspects.md) (8 aspect patterns with
  code sketches).
- Declaring hosts → [host-definition](concepts/host-definition.md) (the
  `mkNixos` + per-host `flake-parts.nix` + host-as-feature trio, plus
  mightyiam/infra and drupol/infra variants).
- Home-manager (embedded per-user, sharedModules, standalone) →
  [multi-context-home-manager](concepts/multi-context-home-manager.md).
- Planning THIS repo's migration →
  [migration-plan-notes](syntheses/migration-plan-notes.md) (mapping table of
  flake.nix/modules → dendritic targets, risks: aarch64 slinky, standalone HM
  pkg config, pre-commit, disko images, sops data dir, double imports).
- Settled plan (grilling 2026-10-21, ADR-0014) →
  [adopted-plan](syntheses/adopted-plan.md) (target tree, flake-file
  workflow, per-host conversion recipe).

## Sources

1. [mightyiam/dendritic](sources/dendritic-pattern.md) — canonical definition
   + anti-patterns.
2. [Doc-Steve guide](sources/doc-steve-guide.md) — Basics / Dendritic_Aspects
   / Comprehensive_Example / FAQ, example-repo findings.
3. [flake.parts](sources/flake-parts.md) — mkFlake, perSystem, systems,
   module arguments, flake.modules.
4. [import-tree](sources/import-tree.md) — upstream helper; local copy diff.
5. [flake-file](sources/flake-file.md) — denful/flake-file deep-dive: option
   schema (`flake-file.inputs.*`), `flakeModules.dendritic` internals,
   write-flake/check-flake-file loop, flake.lock non-invasiveness, Dendrix
   property list.

## Glossary quick-link

Repo-root [GLOSSARY.md](../../../GLOSSARY.md) defines Image, Installed
footprint, Update independence (repo vocabulary, not wiki vocabulary).

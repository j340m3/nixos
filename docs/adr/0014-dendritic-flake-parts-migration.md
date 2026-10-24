# ADR-0014: Adopt the Dendritic Pattern with flake-parts (canonical restructure)

**Date**: 2026-10-21
**Status**: accepted
**Deciders**: jeromeb + dendritic adoption session (grilling)
**Knowledge**: docs/wiki/ (sources/dendritic-pattern.md, sources/doc-steve-guide.md, sources/flake-file.md)

## Context

The repo is already flake-parts-based, but half the tree predates the pattern:
NixOS modules are plain modules wired by relative-path import piles per host
(`modules/hosts/*/default.nix` imports `../../../modules/common` which itself
aggregates ~15 modules and hard-enables settings), `flake.lib.mkNixos` passes
`specialArgs = { inputs; constants }` to every module, and `home/` exists as a
standalone HM tree while hosts configure HM separately — three coexisting
idioms whose content can drift apart. The dendritic pattern
(github.com/mightyiam/dendritic, popularized by Doc-Steve's guide) flips the
configuration matrix bottom-up: self-contained *features* that publish *aspects*,
with hosts listing the features they use.

## Decision

Adopt the full dendritic end state with **canonical restructure**, no
anti-patterns:

1. Every `.nix` under `modules/` is an auto-imported flake-parts module via
   denful/import-tree, and the flake skeleton is the flake-file setup
   (per-feature input declarations in feature modules, generated flake.nix,
   `flakeModule.dendritic` for the plumbing).
2. NixOS/HM content is stored as aspect values
   (`flake.modules.nixos.<aspect>`, `flake.modules.homeManager.<aspect>`;
   kebab-case keys = path names) and lies dormant until imported.
3. Hosts are features: `modules/hosts/<name>/default.nix` defines
   `flake.modules.nixos.<name>` importing sibling files relatively; the
   `flake-parts.nix` one-liner declares
   `flake.nixosConfigurations = self.lib.mkNixos "<system>" "<name>"`.
4. `specialArgs` (inputs/constants pass-through) are retired once the last
   host converts: NixOS features reach inputs/constants via closures computed
   in flake-parts module scope; constants become a feature.
5. The `modules/common` grab-bag becomes a `system-default` base feature,
   imported exactly once by each host (no double import on one hierarchy
   path). Per-feature opt-outs that are imported-everywhere (e.g.
   `upgradeHealth.enable`) are the dendritic-legitimate use of `enable`.
6. Home-manager is one-source: `home/` becomes
   `flake.modules.homeManager.<aspect>` features consumed by hosts via
   in-tree HM; the standalone `flake.homeConfigurations.jeromeb` stays as a
   thin wrapper around the same aspects (custom pkgs handling preserved
   there) until it can be retired.
7. Target tree (canonical layout):
   `modules/{nix,system,hosts,desktop,services,home,users}` per
   `syntheses/adopted-plan.md`; secrets data and scripts stay outside
   `modules/`.
8. Rollout: skeleton first, then zurg as tracer host (`just check` green +
   `just test zurg` before `switch`), remaining hosts one commit each
   (bootstrap(-impermanent) late — disko image outputs must keep their names:
   `image`, `image-impermanent`), aspects stay keyed by host name.
9. Dendritic anti-patterns designed out: specialArgs pass-thru, unneeded
   `enable` fanfare, module-name proliferation, double imports, relative-path
   import piles.

## Alternatives Considered

### Minimum-move restructure (keep current paths, convert bodies only)
- **Pros**: smallest diff; no path churn, no Justfile risk.
- **Why not**: the operator chose the guide's canonical layout ("path names
  the feature" everywhere, one tree, no legacy dirs).

### Hand-written flake.nix + import-tree input only (skip flake-file)
- **Pros**: no new generator dependency; unchanged input topology;
  no lockfile churn risk.
- **Why not**: full canonical adoption includes flake-file's per-feature
  input declarations and generated flake.nix; the hand-tuned `follows`
  graph migrates into the input declarations.

### Hybrid end state (keep specialArgs, incrementally share)
- **Why not**: two idioms in one tree; the dendritic README names
  specialArgs pass-thru as an anti-pattern; upgrade target was scoped as
  "full, no anti-patterns".

### den framework (drupol-style aspects/includes)
- **Why not**: second framework on top of flake-parts; the guide's
  flake-parts idioms are already sufficient here.

## Consequences

### Positive
- Adding/removing a feature touches one self-contained file; hosts shrink to
  feature lists; free file reorganization; no relative-path piles.
- HM content stops drifting between the standalone tree and host entries.
- Inputs are declared where they are used; flake.nix becomes generated
  boilerplate.
- `just check` (+ per-system eval-checks) remain the green bar after every
  conversion; aarch64 slinky unaffected (`systems` stays x86-only, eval-check
  filter preserved, NixOS configures its own pkgs).

### Negative
- One-time churn across all 11 live hosts; the hand-tuned `follows` graph is
  transcribed into `flake-file.inputs` declarations and flake.nix becomes a
  generated file (no at-a-glance input overview). **flake.lock is untouched
  by default** — flake-file only ever rewrites flake.nix and fails
  `checks.check-flake-file` on drift.
- New dependency and workflow (regenerate via `nix run .#write-flake` after
  any `flake-file.*` change; bootstrap command documented in
  syntheses/adopted-plan.md). The lock-mutating flake-file opt-ins
  (auto-follow, prune-lock/allfollow-style lock rewriters) stay OFF.
- Transition period runs two host idioms in parallel (factory supports
  converted and unconverted hosts) until the last host converts; only worth
  it because the end state deletes the second one.

### Risks
- A broken conversion of one shared feature can break many hosts at once —
  mitigated by the eval-check bar (`just check`) catching it before switch.
- typo-roulette on aspect keys is gone once checked (class-typed imports
  surface wrong-class mistakes loudly).
- sops secrets and other data stay *outside* the auto-import tree (data is
  not a feature module); the `/_`-exclusion convention parks dead code.

## Status update (2026-10-24): adoption complete

Waves 3-5 landed in three days of execution; the end state above is
realized everywhere. Supersessions of the wording above:

- Point 3 in practice: hosts are **two-file features** —
  `configuration.nix` (the feature body) + `flake-parts.nix` (the
  `mkNixos` declaration). Zero host-local glue remains: the 12 per-host
  `_hardware-configuration.nix` / `_disk-config.nix` / `_local.nix` /
  `_uConsole.nix` siblings were absorbed inline into the host body, and
  lenny's two boot specialisations collapsed into the base config
  (both tags `jeromeb` and `lilly` kept; the `_module.args.inputs` hook
  died with them).
- Users and desktops became aspects too (`modules/users/{jeromeb,donquezz}`,
  `modules/desktop/{kde,xfce}`), replacing the last root path-import dirs.
- Point 7 final layout: `global/{constants,peers}` moved under
  `modules/global/` — constants is `modules/global/_constants.nix`
  (underscore = import-tree exclusion, now load-bearing for a data file);
  `secrets/` and `scripts/` stay at root, matching the exemplar tree.
- slinky flags: eval-green to the IFD build wall (aarch64 kernel), but
  hardware verification on the actual uConsole is still pending —
  treat slinky as adopted-pending-live-verify.
- Green bar between waves: full `just check` (10 ok + slinky skip,
  aarch64) before every commit.

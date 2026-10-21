# Migration-plan notes: this repo → dendritic-with-flake-parts

Repo state as of 2026-10-21 (read from flake.nix, modules/flake/{lib,home,per-system}.nix,
modules/common/default.nix, modules/hosts/woody/{default,flake-parts}.nix). Sources:
[doc-steve-guide](../sources/doc-steve-guide.md), [dendritic-pattern](../sources/dendritic-pattern.md),
[flake-parts](../sources/flake-parts.md), [import-tree](../sources/import-tree.md),
also to blend [host idioms](../concepts/host-definition.md) and
[HM integration](../concepts/multi-context-home-manager.md).

## 1. "Deliberately NOT auto-imported" vs dendritic "all imported"

flake.nix:82-87 says: "this entry file only wires the inputs and auto-imports
that tree [modules/flake] plus each host's self-declaration (modules/hosts/*/
flake-parts.nix). NixOS modules (modules/*.nix, modules/hosts/*) are
deliberately NOT auto-imported here: they are NixOS modules, not flake-parts
modules". This looks like a conflict with dendritic's "every file imported",
but the two statements are at different levels:

- Dendritic auto-imports **top-level (flake-class) modules only** — and in a
  dendritic repo *every* module is a flake-parts/top-level module.
- The current NixOS modules are *lower-level* modules (class `nixos`); they
  are not auto-imported as NixOS modules but **stored as option values**
  (`flake.modules.nixos.<feature>`) and merged into any
  `nixosConfigurations` evaluation via `imports` of those aspect values.

So full adoption does not mean "every NixOS module gets evaluated on every
host": it means "every file becomes a flake-parts module; NixOS content moves
into aspect definitions". The host that uses feature X imports it; features
the host doesn't import are only *defined*, never evaluated (same semantics
in the comprehensive example: `linux-desktop` doesn't import `gnome` → gnome
is dead weight only during its aspect definition, which is dormant).

## 2. Concrete mapping (current → dendritic)

| Now | Dendritic target |
|---|---|
| `flake.nix` `importTree ./modules/flake ++ hosts/*/flake-parts.nix` (importTree local copy) | `mkFlake { inherit inputs; } (import-tree ./modules)` — *all* tree `.nix` files become flake-parts modules; add `_` exclusion (import-tree / flake-file `flakeModule.dendritic`) |
| `modules/flake/lib.nix` `self.lib.mkNixos host` + `specialArgs {inputs,constants}` + imports host dir path | `mkNixos = system: name: { ${name} = nixosSystem { modules = [ self.modules.nixos.${name} { nixpkgs.hostPlatform = mkDefault system; } ]; }; }` — aspect-keyed, no specialArgs; `options.flake.lib` freeform |
| `modules/flake/per-system.nix` (systems, perSystem pkgs/images/devShell/checks/pre-commit) | stays a flake-parts module; unchanged shape; move to e.g. `modules/nix/` feature dir; `systems = [ "x86_64-linux" ]` preserved |
| `modules/flake/home.nix` standalone `homeConfigurations."jeromeb"` | `mkHomeManager` helper variant; HM tree `home/` becomes `flake.modules.homeManager.<name>` aspects (see multi-context note) |
| `modules/common/default.nix` (aggregator of ~15 NixOS modules + `users/donquezz.nix`) | a *base/default system feature* (inheritance-resident `system-default` in the example is the same idea): `flake.modules.nixos.system-default = { imports = with inputs.self.modules.nixos; [ update upgrade-health ssh ssh-identities reticulum locale sops rateLimitingAvoidance zram domain distributed-builds mem ulimit peerpatrol agentMd ]; };` — or, more idiomatically, one feature per file and the host imports the *aggregate* |
| `modules/hosts/woody/default.nix` imports block (hardware-configuration, common, donquezz, loghost, borg-server, kde, wifi, immich, paperless, xrdp, nas, nofile, firefox, power, zabbix, home-assistant, harmonia, nfs-fee, nebula, prometheus, grafana, fritz-exporter, chaotic.nixosModules) | `flake.modules.nixos.woody = { imports = with inputs.self.modules.nixos; [ system-default desktop-kde wifi loghost borgServer immich /* ... */ inputs.chaotic.nixosModules.default ]; };` — external modules stay imported by path; relative `../../../` paths disappear (move feature files freely, Basic's "path independence") |
| `global/constants.nix` + `specialArgs.constants` | dendritic anti-pattern (specialArgs pass-thru) → constants aspect (`generic` class) or a `<flake class>` option (Collector aspect note: the peerpatrol fleet-roster check reads `constants.host` — as a sync it could read a flake-level option or the configuration itself, e.g. all nixosConfigurations with a nebula-ip option) |
| `boot.kernelPackages = cachyos-lto` etc. per-host inline settings | these stay in the host feature; *cross-cutting* ones (locale/timezone duplication across hosts) move into a feature or a `system-default` |

Collector-based conversions to watch (multiple hosts set per-identity values
into one aspect name): syncthing-style devices aren't present, but
`peerpatrol` (roster in constants + sops secret paths) and `nebula` (per-host
ips) are exactly the collector aspect use-case: each host feature adds
`flake.modules.nixos.peerpatrol = { /* its tokens/targets */ };`.

## 3. Risks & sharp edges (verify each before migrating)

- **aarch64 host slinky**: `systems = [ "x86_64-linux" ]` controls perSystem
  only; nixosConfigurations are arch-agnostic. The per-system eval-check
  filter (`cfg.config.nixpkgs.hostPlatform.system == system`,
  per-system.nix:96-105) must be kept — dendritic changes nothing here, but a
  "share pkgs via withSystem" refactor (flake-parts system.md Approach 2)
  breaks on foreign-arch hosts unless gated by hostPlatform. Keep Approach 1
  (NixOS configures its own nixpkgs) — woody needs `allowUnfree`, VMs skip
  it; centralized `readOnlyPkgs` pkgs can't express that per-host.
- **home-manager standalone** (modules/flake/home.nix): its custom
  `pkgs = import inputs.nixpkgs { system; permittedInsecurePackages = [ "radicle-node-1.10.3" ]; allowUnfreePredicate spotify/apple_cursor }`
  gotcha must be preserved in whatever mkHomeManager is adopted (the
  comprehensive example's helper just uses `legacyPackages`, which is *not*
  enough here — for the standalone config nobody else supplies the
  permittedInsecurePackages/allowUnfreePredicate, so the local helper's pkgs
  import stays).
- **pre-commit checks + formatter + devShell** (per-system.nix): pure
  perSystem; survives untouched, but deadnix/statix will parse *more* files
  (all tree .nix become modules); the `--no-lambda-pattern-names` arg stays.
- **disko image builders** (per-system.nix:36-66): `mkImage host` uses
  `self.nixosConfigurations.<host>.extendModules` — host *name*-keyed. If
  aspect-keyed configs keep the same output attribute names (`bootstrap`,
  `bootstrap-impermanent`) nothing changes; the `diskoImageCompat` overlay is
  system-specific so it stays in perSystem.
- **sops** (modules/common/sops.nix): converting sops wiring into a feature
  option is fine (declarative), but *secrets files* are data: guide says data
  shared across features lives outside `modules/` (e.g. separate `secrets`
  dir; the comprehensive example has a `secrets` flake-false input). Keep the
  secrets dir outside the auto-import tree.
- **double imports**: Basics WARNING — never import the same module twice on
  one path (e.g. `system-default` importing home-manager AND a user feature
  that also imports it). woody's aggregator imports common + host-level
  modules; every host imports common today, so make `system-default` the
  *only* importer of the base features in each host hierarchy.
- **enable options**: `upgradeHealth.enable` is a legitimate dendritic
  `enable`-option (module imported everywhere, effect per-host opt-in,
  upgradeHealthCheck asserts both sides). `services.reticulum.enable = true`
  in common/default.nix and the `programs.*`/`services.*` enable flips in
  hosts should become *import-of-feature* where the toggle is ours, not a
  nixpkgs-module's option.
- **class typing**: `flake.modules` flags wrong-class imports as type errors —
  NixOS-only options referenced from HM code (e.g. if `home/` ever grows
  sops-nix HM usage) surface loudly; `generic` class is the shared escape.
- **`_`-exclusion**: the local `importTree` has no `_` rule; with
  everything auto-imported, partially-finished features and `callPackage`
  files need the `/_` convention (or import-tree `.filterNot` like
  mightyiam/infra) or the build breaks on stray files.
- **flake-file (optional but the guide's default)**: the doc-steve example
  and both reference repos generate flake.nix with it. Adopting dendritic
  without flake-file is fine (this repo's 20+ inputs declared in flake.nix is
  exactly the "manual editing" flake-file removes; per-feature
  input declarations will be the biggest diff).
- **FAQ migration guidance** applies (FAQ scenario 4): this repo is
  experienced + complex; already flake-parts based and host-declaring (close
  to the pattern!) — the main remaining gap is: NixOS modules as
  `flake.modules.nixos.*` options instead of path-imported trees, hosts
  importing aspects instead of paths, and dropping specialArgs.

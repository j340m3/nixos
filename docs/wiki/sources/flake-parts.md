# flake-parts — notes for dendritic setups

- Source pages (docs site rebuilt as mdBook in 2025/2026; old URLs
  `overview_mkFlakeOptions`, `distribute-packages`, `module-merge` 404 now):
  - https://flake.parts/getting-started
  - https://flake.parts/system (was distribute-packages)
  - https://flake.parts/module-arguments
  - https://flake.parts/options/flake-parts-modules (the `flake.modules` extra)
  - https://flake.parts/options/flake-parts (core options incl. `perSystem`, `systems`, `withSystem`)

## mkFlake

```nix
outputs = inputs@{ flake-parts, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } (top@{ config, withSystem, moduleWithSystem, ... }: {
    imports = [ ];          # external flakeModules go here
    systems = [ "x86_64-linux" "aarch64-darwin" ];
    perSystem = { config, pkgs, ... }: { packages.foo = pkgs.callPackage ./foo.nix { }; };
    flake = { /* raw flake outputs */ };
  });
```

## systems & perSystem

- `systems` = the list of systems for which `perSystem` attributes are
  instantiated (`perSystem` merges per system; `config.flake.packages.<system>` is produced).
- Things existing on multiple systems → `perSystem`; things that don't
  (machine configurations, deployments) → top-level options like
  `flake.nixosConfigurations` — *not* perSystem.
- Top-level entities need perSystem values via **`withSystem`**; `getSystem`
  and `moduleWithSystem` also exist; inside `perSystem` use `inputs'`/`self'`
  (system-preselected, pronounced "prime") and `pkgs`
  (default `inputs.nixpkgs.legacyPackages.${system}`, overridable via
  `config._module.args.pkgs`).
- **Two ways to configure nixpkgs for NixOS** (system.md): (1) keep
  `nixpkgs.*` config inside each NixOS module; (2) configure pkgs once in
  `perSystem` (`_module.args.pkgs = import inputs.nixpkgs { inherit system; ... }`)
  and feed it to NixOS via `nixpkgs.pkgs = withSystem config.nixpkgs.hostPlatform.system ({ pkgs, ... }: pkgs);`
  plus `nixpkgs.nixosModules.readOnlyPkgs` to freeze it.

## `flake.modules` (extras/modules.nix; import `inputs.flake-parts.flakeModules.modules`)

> "Groups of modules published by the flake. The outer attributes declare the
> class of the modules within it. The special attribute `generic` does not
> declare a class."

- Class-typed: loading a homeManager module into a NixOS config is a *type
  error*, not a cryptic undeclared-options error. Modules can be inline,
  file paths, or a mix (with `imports` + perSystem values via withSystem).

## Module arguments (module-arguments.md)

- Top-level: `config`, `options`, `lib` (from flake-parts' `nixpkgs-lib`),
  `getSystem`, `withSystem`, `moduleWithSystem`.
- `withSystem "x86_64-linux" (ctx@{ config, inputs', ... }: ...)` enters a
  perSystem scope for e.g. building nixosConfigurations that pull packages.
- The nixpkgs-lib input should not be overridden (use `follows` at most).
- **`args@{...}` pitfall**: with `args@` binding you only get explicitly named
  arguments — undeclared named args evaluate to exceptions; use explicit
  named params, or `config.allModuleArgs` (perSystem only).

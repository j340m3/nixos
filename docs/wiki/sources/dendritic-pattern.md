# The Dendritic Pattern (mightyiam/dendritic) — canonical definition

- Source: https://github.com/mightyiam/dendritic (default branch: `master`; README is at repo root, 648 stars as of 2026-10-21)
- Author: Shahar "Dawn" Or (@mightyiam). MIT.
- Companion: dendrix (https://dendrix.denful.dev/Dendritic.html) — Vic's summary.

## What it is

> A Nixpkgs module system usage pattern.

It reconciles: multiple configurations, module sharing across them, multiple
configuration *classes* (`nixos`, `home-manager`, `...`), nested configs
(HM inside NixOS/darwin), cross-cutting concerns, and sharing of values
(functions, constants, packages) across files.

Required skills: Nix language, the nixpkgs module system, and the
[`deferredModule` type](https://nixos.org/manual/nixos/stable/#sec-option-types-submodule).

## Core mechanism

A second application of the module system — a *top-level configuration* —
declares and evaluates the lower-level ones (NixOS, home-manager, nix-darwin).
Commonly implemented with flake-parts, but any `lib.evalModules` config works.

## The property list (from README, near-verbatim)

The pattern: *every Nix file except for entry points such as `default.nix`
and `flake.nix` is a module of the top-level configuration.* Every file that
isn't an entry point is a nixpkgs-module-system module imported directly into
the evaluation of the top-level configuration. Additionally, every
top-level module:

- implements a **single feature**
- ...**across all configurations that the feature applies to**
- **is at a path that serves to name that feature**

Lower-level modules and configurations (NixOS, home-manager, nix-darwin) are
stored as **option values in the top-level configuration**. Lower-level
modules take part in the evaluation of **any number** of lower-level
configurations.

Lower-level module merging: the `deferredModule` type (and similar) enables
value merging — many lower-level modules can merge under one name, e.g. two
files both writing `nixos.modules.pc = { ... }` merge.

## Benefits claimed (README headers)

- **Type of every file is known** — non-entry-point files are modules of the
  same class as the top-level configuration; "what's in that nix file?" becomes
  irrelevant.
- **Automatic importing** — all files can be imported with a trivial
  expression or a small library (vic/import-tree).
- **File path independence** — a path names a feature; files can be renamed,
  moved, split freely.

## Anti-patterns (README)

- **Not declaring options**: relying only on existing stores (flake-parts'
  `flake.modules`) prevents translating the mental model into code. Declare
  your own deferredModule options:
  ```nix
  # modules/nixos/base.nix
  { lib, ... }: { options.nixos.base = lib.mkOption { type = lib.types.deferredModule; }; }
  ```
  and compose: `config.nixos.pc = config.nixos.base;`
- **`specialArgs` pass-thru**: dead in dendritic — every file is a top-level
  module and *adds to and reads from the top-level `config`* instead of
  threading `inputs`/`self` through `specialArgs`/`extraSpecialArgs`.
- **Lower-level module name proliferation**: don't give every module its own
  name (import lists explode and churn); merge non-distinct modules under one
  name.
- **Fanaticism**: it's a pattern, not a religion. `callPackage` files may be
  interspersed if excluded from auto-import (suggested naming: `my-package.pkg.nix`;
  see mightyiam/infra which does `(import-tree).filterNot (lib.hasSuffix ".pkg.nix")`).
- **`enable` options**: importing a module should *enable* the feature it
  provides. `enable` options are only for modules that are imported but whose
  effect must stay optional.

## Real examples

mightyiam/infra (with adoption commit), vic/vix, drupol/infra,
Horizon Haskell, GaetanLepage/nix-config, quasigod/nixconfig,
opdavies/nix-config, eveeifyeve/Nix-Config.

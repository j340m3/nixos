# import-tree — upstream helper this repo reimplemented locally

- Sources: https://github.com/denful/import-tree (was vic/import-tree; GitHub
  links in Doc-Steve wiki and flakes still use
  `github:vic/import-tree`, which resolves to denful), README repo root, source
  `tree/default.nix` (inspected 2026-10-21, rev main, Apache-2.0).
- Docs: https://import-tree.denful.dev
- One-liner: "Recursively import Nix modules from a directory, with a simple,
  extensible API." Built to enable the Dendritic Pattern on stable/unstable Nix.

## Usage

```nix
outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
```

Works without flake-parts too:
```nix
outputs = inputs: (inputs.nixpkgs.lib.evalModules {
  specialArgs.inputs = inputs;
  modules = [ (inputs.import-tree ./modules) ];
}).config;
```

## Default behaviour (verified against source + fixture tree)

Default nix filter in `tree/default.nix`:

```nix
nixFilter = andNot (hasInfix "/_") (hasSuffix ".nix");
```

- Imports **only files ending in `.nix`** (the fixture has `a.txt` and an
  extensionless file `hello/world` that are *not* imported → it does **not**
  import other file types).
- Excludes any path segment starting with `_` (`/_` infix): `_foo.nix` files,
  `_parked/` dirs and everything below them (README: "By default, paths
  having `/_` are ignored" — Doc-Steve's Basics calls this the way to disable
  unfinished code).
- The reader is pure `builtins` (no nixpkgs lib needed, deps-free).

## API beyond default

- Chainable: `.filter f`, `.match regex` (+ matchNot / filterNot), `.map fn`,
  `.addAPI` for domain-specific instances.
- `viewModel`-style `files` attribute; explicit user-supplied (non-directory)
  root files bypass the filter.

## Relation to this repo

flake.nix:102 carries a local `importTree` copy ("Same idea as vic's
import-tree; local copy so the flake does not grow an extra input for a
10-line helper"). Differences vs upstream:

| | local `importTree` (this repo) | denful/import-tree |
|---|---|---|
| file types | `.nix` only | `.nix` only (default) |
| `_`-prefix exclusion | none | yes (`/_` infix) |
| chainable filter API | none | yes |
| input | none (inline) | +1 flake input |

Migration note: adopting dendritic auto-import of *everything* makes the `_`
exclusion practically important (commented-out or partial feature files need
somewhere to live); either adopt import-tree/flake-file's
`flakeModule.dendritic`, or extend the local helper with the `_` rule.

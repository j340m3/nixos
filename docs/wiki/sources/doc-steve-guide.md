# Doc-Steve guide: dendritic design with flake-parts

- Source: https://github.com/Doc-Steve/dendritic-design-with-flake-parts (wiki + example repo)
- Full guide index: wiki "Home". The example repo lives at the same URL (main branch),
  uses vic/import-tree + vic/flake-file, brackets in dir names like `homeserver [N]`.
- Companion summary: [Dendritic Nix by Vic](https://dendrix.denful.dev/Dendritic.html).

## Basics (wiki/Basics)

- **Paradigm shift — "flipping the configuration matrix"**: not *host has
  services/users/settings* top-down, but *feature is used on hosts* bottom-up.
  A **feature** bundles the settings for all contexts it touches (NixOS,
  nix-darwin, home-manager), and "everything necessary".
- Features are **modules of the `<flake class>`** (flake-parts modules); they
  define `aspect`s (named lower-level modules, e.g.
  `flake.modules.nixos.syncthing`) plus *flake-parts boilerplate* (e.g. the
  `nixosConfigurations` wiring). All feature modules are imported at flake.nix
  (auto-import), but an aspect *definition* is inactive until used by some
  boilerplate/other module.
- **Feature granularity**: services/apps ("syncthing"), categories
  ("codingApps"), usage areas ("desktopEnvironment"), users or hosts ("bob",
  "myServer"), user/host categories ("adminUser"), Nix tools ("impermanence").
- **`flake.modules.<class>.<aspect>`** stores reusable building blocks;
  classes: `nixos`, `darwin`, `homeManager`, and `generic` (usable in any
  class). Enabling is replaced by **importing**: a module's content enables
  its feature by default.
- **File organization**: all features under `modules/`, one dir per feature;
  split files freely; keep internal refs independent of dir names; data for
  one feature lives in its dir, shared data (e.g. secrets) in a top-level data
  dir.
- **Pitfalls** (Basics, WARNING block): imports are class-typed (NixOS module
  into darwin = error; use `generic` to share); imports must never be
  conditional (`lib.mkIf` around `imports` = broken recursion); never import
  the same module multiple times on one hierarchy path.
- Auto-import snippet:
  ```nix
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
  ```
  import-tree also excludes `_*`-prefixed paths (park unfinished code).
- **vic/flake-file** (optional): inputs declared per feature; `flake.nix`
  auto-generated (`DO-NOT-EDIT ... nix run .#write-flake`). flake-file ships
  `flakeModule.dendritic` which sets up flake-file/import-tree/flake-parts in one import.
- Convenience helper (stored in `flake.lib` freeform option):
  ```nix
  mkNixos = system: name: {
    ${name} = inputs.nixpkgs.lib.nixosSystem {
      modules = [
        inputs.self.modules.nixos.${name}
        { nixpkgs.hostPlatform = lib.mkDefault system; }
      ];
    };
  };
  ```

## Comprehensive Example (wiki/Comprehensive_Example)

Structure of the example repo: `flake.nix`, `modules/{factory,hosts,nix,programs,services,system,users}`.

- **Bracket naming**: dir name = feature name; brackets list usage classes:
  `N`=NixOS, `D`=darwin, lowercase `n`/`d` = home-manager on that system, `G`=generic,
  `[networkInterfaces]` = custom class, `[FL]`/`[]` = flakeParts.
- **Host definition** (exact idiom, verified in example source):
  ```nix
  # modules/hosts/homeserver [N]/flake-parts.nix
  { inputs, ... }: {
    flake.nixosConfigurations = inputs.self.lib.mkNixos "x86_64-linux" "homeserver";
  }
  ```
  ```nix
  # modules/hosts/homeserver [N]/configuration.nix
  { inputs, ... }: {
    flake.modules.nixos.homeserver = {
      imports = with inputs.self.modules.nixos; [ system-cli systemd-boot impermanence ];
    };
  }
  ```
  `mkNixos`/`mkDarwin`/`mkHomeManager` helpers live in
  `modules/nix/flake-parts [FL]/lib.nix` behind
  `options.flake.lib = mkOption { type = types.attrsOf types.unspecified; }`.
  Host subdirs (services/, users/) add *collector-style extra definitions* of
  aspect names (e.g. `flake.modules.nixos.syncthing` merges device data from
  the host dir).
- `system/system types/` holds `system-minimal → system-default → system-basic
  → system-cli → system-desktop` inheritance chain that every host/user picks
  one of ("best practice: a `default` feature").
- flake-file-generated flake.nix contains only inputs + the import-tree one-liner.
- Packages (callPackage) live outside `modules/` (e.g. `packages/`,
  `pkgs-by-name` tool feature); secrets dir is separate (`path:./secrets`
  input) — data files are not feature modules.

## FAQ (wiki/FAQ)

- It is a *software design pattern*, not a library/framework. Two main
  principles: **top-level modules** (everything built from one type of module,
  which defines lower-level ones) and **features** (the building blocks).
- Advantages: multi-platform co-existence per feature; simple self-contained
  building blocks; adding/removing = features; less glue/enable code; reuse;
  consolidated bug-fixing; free file re-organization; no `specialArgs`;
  uniform file semantics; empty-ish flake.nix (lose at-a-glance output overview).
- Drawbacks: depends on the framework ecosystem for top-level plumbing
  (risk, lock-in) — flake-parts chosen as the most widely used, minimal option
  (14,000+ flakes on GitHub); non-flake alternative: vic/dendritic-unflake;
  wrappers on flake-parts: vic/den, quasigod/unify.
- Migration guidance: (3) complex+unstable setup → no-brainer; (4) very
  experienced, complex, *stable* setup with flake-parts-style structure and
  "roles" already in place → trade-off, "if you're happy with your current
  setup, there's nothing wrong with sticking with it".
- Aspect patterns are optional inspiration, not mandates.

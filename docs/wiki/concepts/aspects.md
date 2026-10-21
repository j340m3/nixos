# Dendritic aspect patterns (catalog)

Source: https://github.com/Doc-Steve/dendritic-design-with-flake-parts/wiki/Dendritic_Aspects
(fetched 2026-10-21). See also [doc-steve-guide source note](../sources/doc-steve-guide.md).

One *feature* (a flake-parts module, the `<flake class>`) may define several
*aspects* — one per module class. The tails of the single root module always
fall on the feature's own aspects — aspect patterns never change that.

## Simple aspect
One aspect per class, no dependency on other features. Same feature can carry
`nixos`, `darwin`, `homeManager` variants of the same name.

```nix
{
  flake.modules.nixos.basicPackages = { pkgs }: { environment.systemPackages = [ /* ... */ ]; };
  flake.modules.homeManager.basicPackages = { pkgs }: { programs = { /* ... */ }; };
}
```

## Multi-context aspect
A feature only ever *used* in one class (e.g. nixos) but must also set
mandatory config in a nested class (e.g. home-manager). Main module +
private auxiliary module; the main module imports the auxiliary one into the
nested context.

```nix
{ inputs, ... }: {
  flake.modules.nixos.gnome = {
    home-manager.sharedModules = [ inputs.self.modules.homeManager.gnome ];
    /* system-level gnome config */
  };
  flake.modules.homeManager.gnome = { /* aux module, HM options */ };
}
```

## Inheritance aspect
Extend/modify existing aspects by importing the parent per class.

```nix
{ inputs, ... }: {
  flake.modules.nixos.system-desktop = {
    imports = with inputs.self.modules.nixos; [ system-cli  mail  browser  kde  printing ];
  };
}
```
WARNING: when combined with multi-context aspects, avoid importing the same
auxiliary module twice (e.g. two paths both adding to `home-manager.sharedModules`).

## Conditional aspect
Conditionally merged parts *inside* the module body — never around `imports`.

```nix
flake.modules.homeManager.office = { pkgs, lib, ... }: lib.mkMerge [
  { home.packages = [ pkgs.notesnook ]; }
  (lib.mkIf pkgs.stdenv.isLinux  { home.packages = [ pkgs.libreoffice-qt6 ]; })
  (lib.mkIf pkgs.stdenv.isDarwin { home.packages = [ pkgs.libreoffice-bin ]; })
];
```

## Collector aspect
Global feature whose config gets *additional* definitions from other features
under the **same class+aspect name** (module-system merging). E.g. feature
`syncthing` defines `services.syncthing.enable = true;`; a host feature
"homeserver" adds:

```nix
# feature homserver
flake.modules.nixos.syncthing = { services.syncthing.settings.devices.homeserver.id = "VNV2-..."; };
```
The class-typed `flake.modules` option solves this natively (all definitions
under one name merge); with hand-rolled options this is the `deferredModule`
case. The example repo stores per-host contributions as separate files in the
host's dir. This replaces central constant files (this repo's
`global/constants.nix` roster use-case).

## Constants aspect (`generic` class)
Define options + set values, import once high up so all modules in the tree
can read them. Constants *and functions* (becomes a "library aspect").

```nix
{
  flake.modules.generic.systemConstants = { lib, ... }: {
    options.systemConstants = lib.mkOption { type = lib.types.attrsOf lib.types.unspecified; default = { }; };
    config.systemConstants.adminEmail = "admin@test.org";
  };
}
```
```nix
flake.modules.nixos.system-default.imports = [ inputs.self.modules.generic.systemConstants ];
# later: services.zfs.zed.settings.ZED_EMAIL_ADDR = [ config.systemConstants.adminEmail ];
```
Cheaper alternative: set values directly at the `<flake class>` (`let` value
or an `options.<name>` in a feature module), then read via `inputs.self.<name>`.

## DRY aspect (custom class)
Reusable *attribute-set fragments* for "attribute set of (submodule)" leaks
like `networking.interfaces.<name>.*`, where names are dynamic. Encapsulated
in a new custom class; assignments merge with `lib.mkMerge` (never `//`).
Real repos: a per-user module class analogous to this exists in
drupol/infra (`den.schema.user.classes = [ "homeManager" ]`, modules/dendritic.nix).

```nix
flake.modules.networkInterface.subnet-A = { ipv6.routes = [ { address = "..."; prefixLength = 64; via = "xxx"; } ]; /* ... */ };
```
```nix
networking.interfaces."enp86s0" = with self.modules.networkInterface; lib.mkMerge [ subnet-A subnet-B { ipv4.addresses = [ /* ... */ ]; } ];
```

## Factory aspect
A *function* stored in a library (e.g. `options.flake.factory` freeform
option) that produces modules/aspects from parameters. Two variants:
(1) returns a `flake.modules`-shaped attrset with (dynamic) aspect names;
(2) returns an anonymous module of one class, used in `imports`.

```nix
config.flake.factory.user = username: isAdmin: {
  nixos.${username} = { users.users.${username} = { name = "${username}"; extraGroups = lib.optionals isAdmin [ "wheel" ]; /* ... */ }; };
  darwin.${username} = { /* ... */ };
};
# usage:
flake.modules = lib.mkMerge [ (self.factory.user "bob" true) { nixos.bob = { /* extra customization */ }; } ];
```

## Selection: one feature, many patterns
Requirements for feature `bob`: nixos+darwin → (A) simple; HM inside system
config → (B) multi-context; reuses adminTools/videoEditing → (C) inheritance;
also usable as standalone HM "bob" → (D) simple: the auxiliary HM module from
(B) *is* the public HM module. Combined sketch (see multi-context note).

## Cross-cutting pitfalls
- `lib.mkMerge` instead of `//` when merging module parts.
- Never `mkIf` around `imports`.
- Class typing of `flake.modules` will flag wrong-class imports; use `generic`.
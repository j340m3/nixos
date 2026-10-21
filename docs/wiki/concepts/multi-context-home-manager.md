# Multi-context home-manager integration (dendritic)

Sources: Doc-Steve wiki Basics ("module classes") + Dendritic_Aspects
("Multi Context", "Conditional"), Comprehensive_Example repo source
(`modules/nix/tools/home-manager [ND]/`), flake-parts options
(flakeModules), flake.parts docs. Fetched 2026-10-21.

## The tool feature itself (once per repo)

```nix
# modules/nix/tools/home-manager [ND]/flake-parts.nix
{
  flake-file.inputs = {
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };
  imports = [ inputs.home-manager.flakeModules.home-manager ];  # flake-parts module
}

# home-manager.nix — one NixOS aspect + one darwin aspect
{
  flake.modules.nixos.home-manager = {
    imports = [ inputs.home-manager.nixosModules.home-manager home-manager-config ];
  };
  flake.modules.darwin.home-manager = {
    imports = [ inputs.home-manager.darwinModules.home-manager home-manager-config ];
  };
  # home-manager-config sets: useUserPackages, useGlobalPkgs, backupFileExtension, ...
}
```
Every system aspect that wants HM per-user imports this feature
(`system-default` imports it in the example) — importing *once* in the
hierarchy so H-M is not loaded twice (double-import warning, Basics).

## Per-user bridging (the "bob" idiom)

User feature = simple aspect (A) + multi-context aspect (B):

```nix
{ inputs, ... }: {
  flake.modules.nixos.bob = {
    home-manager.users.bob = { imports = [ inputs.self.modules.homeManager.bob ]; };
    imports = with inputs.self.modules.nixos; [ desktopEnvironment ];
    # NixOS user settings (users.users.bob, etc.)
  };
  flake.modules.darwin.bob = {
    home-manager.users.bob = { imports = [ inputs.self.modules.homeManager.bob ]; };
    /* darwin user settings */
  };
  flake.modules.homeManager.bob = {
    imports = with inputs.self.modules.homeManager; [ adminTools videoEditing ];
    # HM-only settings
  };
}
```
The HM module is a *named public aspect*: (B)+the auxiliary-module trick means
(D) costs nothing — the same module powers embedded and standalone HM.

## Auxiliary modules for cross-feature HM settings (gnome idiom)

A system feature that needs HM settings for *its* scope routes an HM module
into `home-manager.sharedModules`:
```nix
flake.modules.nixos.gnome = {
  home-manager.sharedModules = [ inputs.self.modules.homeManager.gnome ];
};
```
Repurposing such a private aux module as a public one later is a design move
the guide explicitly endorses.

## Real features posed as HM classes

Features usable "by" both NixOS and darwin (via HM) get one homeManager
module; system incompatibilities handled with the **conditional aspect**
(`lib.mkIf pkgs.stdenv.isLinux` / `isDarwin` inside the HM module), never
around imports. A shared data-only trick: system-level options consumed by HM
sources must exist under both NixOS and darwin — example notes that
impermanence-like NixOS-only options require care before HM code touches them.

## Standalone HM configurations

```nix
# flake's mkHomeManager helper (comprehensive example lib.nix)
mkHomeManager = system: name: {
  ${name} = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages.${system};
    modules = [ inputs.self.modules.homeManager.${name} { nixpkgs.config.allowUnfree = true; } ];
  };
};
```
This repo already does the standalone flavor (modules/flake/home.nix,
`homeConfigurations."jeromeb"`, importing `home/`); the dendritic move is: HM
modules live in `flake.modules.homeManager.<aspect>`, and per-user home dirs
(`home/`) each become aspect names.

## Alternatives (same goal, other tools)

- vic/den / denful/den — aspect-oriented `.includes` lists (drupol/infra uses
  it; `den.schema.user.classes = [ "homeManager" ]` declares the user class).
- quasigod/unify — "define multiple types of Nix configs in the same modules".
- home-manager's flakeModule (`flakeModules.home-manager`) integration is
  orthogonal to all of these: it turns HM module trees into flake-parts
  modules rather than a separate home-manager evaluation outside mkFlake.

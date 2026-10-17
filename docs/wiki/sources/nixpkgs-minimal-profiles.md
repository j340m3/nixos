---
title: nixpkgs minimal profiles (minimal/headless/perlless/bashless/image-based-appliance)
url: file:///nix/store/r5l65vg4gi4dnx54zkwagfb8jmlqniy5-source/nixos/modules/profiles/
kind: primary
accessed: 2026-10-16
---

# nixpkgs `nixos/modules/profiles/*` (26.11pre-git)

Local nixpkgs checkout `/nix/store/r5l65vg4gi4dnx54zkwagfb8jmlqniy5-source`.
Authoritative option names/defaults. All profile values are `mkDefault` (except
where noted), so host config can override.

## `minimal.nix`

Turns off (all `mkDefault`): `documentation.{enable,doc,info,man,nixos}.enable = false`;
`environment.defaultPackages = [ ]`; `environment.stub-ld.enable = false`;
`programs.command-not-found.enable = false`; `programs.fish.generateCompletions = false`;
`services.logrotate.enable = false`; `services.udisks2.enable = false`;
`xdg.{autostart,icons,mime,sounds}.enable = false`.

Note: does **not** set `environment.noXlibs` (that option was removed — see
`nixpkgs-corepackages-toplevel`).

## `headless.nix`

Disables graphical/GUI-adjacent bits (used by `pricklepants`).

## `perlless.nix`

`system.etc.overlay.enable = true`; `services.userborn.enable = true`;
`system.tools.nixos-generate-config.enable = false`; `boot.loader.grub.enable = false`;
`environment.defaultPackages = [ ]`; `documentation.{info,nixos}.enable = false`;
`programs.command-not-found.enable = false`;
`system.forbiddenDependenciesRegexes = [ "perl" ]` (asserts no store path contains "perl").

## `bashless.nix` (imports perlless)

`system.nixos-init.enable = true`; `system.activatable = false`;
`environment.shell.enable = false`; `programs.bash.enable = false`;
`environment.corePackages = lib.mkForce [ ]`; `nix.enable = false`;
`console.enable = false`; `networking.useNetworkd = true`;
`networking.firewall.enable = false`; `security.enableWrappers = false`;
`boot.kexec.enable = false`; `powerManagement.enable = false`;
`system.forbiddenDependenciesRegexes = [ "bash" ]`.

## `image-based-appliance.nix`

imports `minimal.nix`; `nix.enable = false`; `system.switch.enable = false`;
`users.mutableUsers = false`; `boot.initrd.systemd.enable = true`;
`networking.useNetworkd = true`. For images updated wholesale (e.g. systemd-sysupdate).

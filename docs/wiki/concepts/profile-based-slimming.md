# Concept: Profile-based slimming

**Status:** current · Sources: `nixpkgs-minimal-profiles`,
`nixpkgs-corepackages-toplevel`, `nixcademy-minimizing-images`, `rafael-minimal-closure`.

NixOS ships opt-in profiles that strip whole subsystems. Prefer these over
hand-disabling package by package.

## Profiles (nixpkgs `nixos/modules/profiles/`)

| Profile | Effect | Rebuildable in place? |
|---|---|---|
| `minimal.nix` | docs/basic-utils/udisks2/logrotate/xdg off; empty `defaultPackages` | yes |
| `headless.nix` | no GUI | yes |
| `perlless.nix` | `etc.overlay` + `userborn` replace perl; `forbiddenDependenciesRegexes=["perl"]` | yes |
| `bashless.nix` | builds on perlless; `nixos-init`, no shell/bash/firewall/console/kexec/wrappers | **no** (`nix.enable=false`) |
| `image-based-appliance.nix` | minimal + `nix.enable=false` + `system.switch.enable=false` | **no** |

`perlless` is the deepest cut that still leaves a rebuildable system:
`system.etc.overlay.enable = true` + `services.userborn.enable = true`
(`nixpkgs-minimal-profiles`). Both are still marked experimental. `etc.overlay`
requires `boot.initrd.systemd.enable`; `mutable = false` requires userborn or
sysusers; switchable systems need kernel ≥ 6.6 (`nixpkgs-corepackages-toplevel`).

## Hard cut: drop Nix from the system

`nix.enable = false` + `system.switch.enable = false` removes Nix (~and boost)
and `switch-to-configuration` (~10 MiB C++ stdlib). This is the `bashless`/
`image-based-appliance` territory and is **incompatible with in-place
`nixos-rebuild`** — updates must replace the whole image
(`nixcademy-minimizing-images`). Used for appliances/ISOs, not general servers.

## This repo's fit

`pricklepants` imports `profiles/minimal.nix` + `profiles/headless.nix`. Both
`environment.defaultPackages = []` and `hardware.enableRedistributableFirmware
= false` are therefore already satisfied on it — nothing to gain there.

`perlless.nix` is **blocked by `git` on every host in this repo.** `git`'s
runtime closure drags in the full perl stack (~51 store paths: CGI,
libwww-perl, LWP, HTML::TagCloud, Net::SSLeay, Authen::SASL, …), so
`perlless`'s build-time `system.forbiddenDependenciesRegexes = [ "perl" ]`
assertion fails. Verified 2026-10-16 by building the `pricklepants` toplevel:
the assertion aborted with the perl path list. Reverse-dep scan found the sole
inbound edge is `git` (git-2.55.0 → perl5.42.x). `git` is added to **all**
hosts by `modules/common/update.nix:31-33`. `perlless` also sets
`boot.loader.grub.enable = mkDefault false`, which conflicts with this
BIOS/QEMU guest (would need `lib.mkForce true` to keep booting).

So the perl→perlless lever only unlocks if `git` is dropped from
`systemPackages` (a fleet-wide decision via `update.nix`) or replaced with a
perl-free git build. Anything based on `bashless`/`image-based-appliance`
conflicts with ADR-0000 (update independence) and the hourly
`system.autoUpgrade` — do not apply without an explicit decision.

## Related levers in the same family

- `system.includeBuildDependencies = false` (default) — never enable.
- `system.forbiddenDependenciesRegexes` — an assertion that fails the build if a
  forbidden interpreter is present; a guardrail, not a shrinker.
- `environment.noXlibs` — **removed**; do not use (`nixpkgs-corepackages-toplevel`).

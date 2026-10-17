---
title: I can haz smoller NixOS ISOs? — natkr
url: https://natkr.com/2026-06-19-nixos-but-smol/
kind: primary
accessed: 2026-10-16
---

# natkr — "NixOS but smol" (2026-06-19)

Takes a stock minimal ISO **458 MiB → 183 MiB** by removing functionality.
Basis for `siraben-smallest-iso` (→ 91 MiB). Live-ISO oriented.

## Method / findings

- Build a minimal ISO via `import "${pkgs.path}/nixos/modules/installer/cd-dvd/iso-image.nix"`.
- Stock breakdown of the 458 MiB ISO: `nix-store.squashfs` 416 MiB, initrd 26 MiB,
  kernel bzImage 13 MiB.
- Use `nix why-depends` against `config.isoImage.storeContents` to find *why* a
  package is in the closure (not the toplevel — the ISO has no runtime deps).
- `nix.enable = false` + `systemd.services.register-nix-paths = lib.mkForce {}`
  removes Nix **and Boost** (Boost came in via `nix-util`).
- `environment.defaultPackages = lib.mkForce []` (perl/rsync/strace are defaults).
- `programs/ssh.nix` has no client enable switch; it injects openssh into
  `environment.corePackages`. Workaround: `disabledModules = ["programs/ssh.nix"]`
  plus a stub `options.programs.ssh = lib.mkOption {};` so modules that expect the
  option don't error.
- GRUB installs both BIOS+UEFI (~62 MiB); reset `system.extraDependencies` +
  `environment.systemPackages` to shed it.
- **Kernel modules are ~144 MiB** — a quarter of the image. No runtime-limiting
  hook exists; `system.systemBuilderCommands = lib.mkAfter "rm $out/kernel-modules"`
  removes runtime module loading entirely (load what you need via
  `boot.initrd.kernelModules`/`availableKernelModules`).
- Perl 56 MiB exists only for user/`/etc` activation → replace with
  `system.etc.overlay.enable = true` + `services.userborn.enable = true` (183 MiB).
- Still bundles both `systemdMinimal` and `systemd` (homework).

## Comparison

- Alpine virt ISO ≈66 MiB (v3.24.1) — the practical live-image baseline.
- Conclusion: NixOS minimal is ~7x Alpine; SMSL (Damn Small Linux) ran a desktop
  in less. "For anything serious, don't do this."

## Comment (woile, 2026-06-25) — on an installed 10 GB VPS

Added, and reports **340 MB → 3.6 GB more free space**:
`documentation.enable = false`; `nix.settings.auto-optimise-store = true`;
`nix.gc = { automatic; dates = "daily"; options = "--delete-older-than 2d"; }`;
`services.journald.extraConfig = "SystemMaxUse=50M\nSystemMaxFileSize=10M"`;
`hardware.enableRedistributableFirmware = false`; `zramSwap.enable = true`;
1.5 GB `/swap` file. `nix-store --optimize` → 382.4 MiB; `journalctl --disk-usage`
145.6 MB; `nix-collect-garbage -d` freed 1.5 GiB / 123 paths.

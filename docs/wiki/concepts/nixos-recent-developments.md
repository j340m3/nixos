# Nix/NixOS recent developments (2024–2026)

Status: current as of 2026-10-22. Sources: [nixos-26.05-release-notes](../sources/nixos-26.05-release-notes.md), [nixos-announcements](../sources/nixos-announcements.md).

## Releases

- 24.11 "Vicuña" (2024-11-30), 25.05 "Warbler" (2025-05-23), 25.11 "Xantusia" (2025-11-30), 26.05 "Yarara" (2026-05-30). Each supported 7 months.

## Notable technical changes

- **systemd initrd by default** (26.05): stage 1 now systemd; scripted deprecated, removed in 26.11. LUKS users must set fileSystems."/".device to /dev/mapper/<name>.
- **system.nix entry point** (26.05): configure NixOS without channels; nixos-rebuild/nixos-install load it; supports fetchTarball pinning.
- **dbus-broker default** (26.05): higher performance; switch inhibitor (reboot).
- **Container test backend** (26.05): NixOS integration tests can run in systemd-nspawn (faster, no KVM, GPU bind-mount).
- **Switch inhibitors** (26.05): pre-switch check list; refuse switch on mismatch; force with NIXOS_NO_CHECK=1.
- **nixos-rebuild Python rewrite** now sole implementation (bash removed).
- **Kernel default 6.12 -> 6.18** (26.05).
- **Removed**: profiles/hardened, linux_hardened, linux-rt, reiserfs, ecryptfs, mysql80, promtail, statsd, pyload, uptime, xtreemfs, etc.
- **NVIDIA module** updated to new nvidia-x11 layout; EGL platforms built from source; hardware.nvidia.branch/moduleParams.
- **security.acme** dynamic renewal duration.
- **Dovecot** module uses RFC-42-style settings.
- **fonts.fontconfig.useEmbeddedBitmaps** true by default.

## Governance

- Nix Steering Committee elected 2024 (7 members).
- NixOS Foundation Board rotated 2025-03 under new constitution.
- Framework partnership 2026-01 for hardware support.
- Documentation funding renewed 2026-07.

## Considerations for a NixOS user

- Plan initrd migration before 26.11; test with boot.initrd.systemd.enable.
- Evaluate system.nix for channel-free, reproducible setups.
- Switch inhibitors may block upgrades; set NIXOS_NO_CHECK=1 only if intentional.
- Remove deprecated services/packages before upgrading.
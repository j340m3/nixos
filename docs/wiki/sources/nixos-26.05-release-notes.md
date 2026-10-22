# Source: NixOS 26.05 "Yarara" release notes

- URL: https://nixos.org/manual/nixos/stable/release-notes (section Release 26.05)
- Captured: 2026-10-22
- Type: official release notes

## Key extracts

- Stage 1 (initrd) now systemd by default; scripted deprecated, removal in 26.11. Revert via boot.initrd.systemd.enable = false.
- `system.nix` added as alternative entry point to configuration.nix/flake.nix; allows pinning nixpkgs via fetchTarball without channels; nixos-rebuild/nixos-install can load it.
- Default kernel 6.12 -> 6.18.
- Default D-Bus implementation switched dbus -> dbus-broker (switch inhibitor, reboot required).
- NixOS integration test driver supports systemd-nspawn containers (faster, no KVM, GPU bind-mount).
- Many new services/modules (reaction, tailscale serve, immichframe, dms-shell, etc.).
- Backward incompatibilities: bash nixos-rebuild removed (Python rewrite only); systemd unit install via nix-env removed; linux_hardened/rt removed; reiserfs/ecryptfs removed; profiles/hardened removed; mysql80 removed; promtail removed; systemd.coredump.extraConfig removed; services.stalwart rename; services.jellyseerr -> seerr; etc.
- Switch inhibitors introduced (pre-switch check list of strings).
- switch-to-configuration reloads service on ExecReload change.
- NVIDIA module wiring updated to new nvidia-x11 output layout; EGL platforms built from source.
- security.acme dynamic renewal duration.
- Dovecot module uses RFC-42-style settings.
- fonts.fontconfig.useEmbeddedBitmaps true by default.

## Relevance

Core reference for a NixOS user upgrading to 26.05. Highlights initrd/systemd, system.nix entry point, container test backend, switch inhibitors.